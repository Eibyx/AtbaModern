import 'dart:async';

import 'package:atba/config/constants.dart';
import 'package:atba/models/library_items/downloadable_item.dart';
import 'package:atba/models/library_items/library_item.dart';
import 'package:atba/models/library_items/queued_torrent.dart';
import 'package:atba/models/library_items/torrent.dart';
import 'package:atba/models/library_items/usenet.dart';
import 'package:atba/models/library_items/webdownload.dart';
import 'package:atba/models/torbox_api_response.dart';
import 'package:atba/services/adaptive_poller.dart';
import 'package:atba/services/cache/library_item_cache_service.dart';
import 'package:atba/services/torbox_service.dart';
import 'package:atba/services/torrent_name_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:provider/provider.dart';

/// One shared snapshot and one polling cycle for list, dashboard and details.
/// The scheduler fetches by category, never once per visible row.
class LibraryPageState extends ChangeNotifier with WidgetsBindingObserver {
  final TorboxAPI apiService;
  final LibraryItemCacheService _cacheService;
  late final AdaptivePoller _poller;
  late final Future<void> _initFuture;
  Future<void>? _refreshing;
  final List<LibraryItem> _libraryItems = [];
  bool _disposed = false;
  bool _visible = true;
  bool _foreground = true;
  bool _failedCycle = false;
  bool _isTorrentNamesCensored = false;
  bool _firstView = false;
  bool isLoading = true;
  String? errorMessage;
  DateTime? lastUpdated;
  bool get isStale => lastUpdated == null || errorMessage != null;
  bool get isRefreshing => _refreshing != null;
  List<LibraryItem> get items => List.unmodifiable(_libraryItems);

  bool isSelecting = false;
  bool isSearching = false;
  String _searchQuery = '';
  String _selectedSortingOption = 'Newest';
  final List<String> _selectedMainFilters = [];
  List<LibraryItem> selectedItems = [];
  final searchController = TextEditingController();
  final searchControllerFocusNode = FocusNode();
  final torrentRefreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final webRefreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final usenetRefreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  factory LibraryPageState(BuildContext context) =>
      LibraryPageState.withServices(apiService: context.read<TorboxAPI>());

  LibraryPageState.withServices({
    required this.apiService,
    LibraryItemCacheService? cacheService,
    bool autoStart = true,
  }) : _cacheService = cacheService ?? LibraryItemCacheService() {
    _poller = AdaptivePoller(
      poll: () async {
        await refreshAll();
        if (_failedCycle)
          throw StateError('No se pudo actualizar la biblioteca.');
        return _libraryItems.any(
          (item) => item.active && !item.downloadFinished,
        );
      },
    );
    WidgetsBinding.instance.addObserver(this);
    apiService.setDownloadsPageState(this);
    searchController.addListener(() => setSearchQuery(searchController.text));
    _initFuture = _initialize(autoStart);
  }

  Future<void> get initialized => _initFuture;

  Future<void> _initialize(bool autoStart) async {
    try {
      _libraryItems.addAll(await _cacheService.getAllItems());
    } on Exception {
      errorMessage = 'No se pudo leer la caché local. Se consultará TorBox.';
    }
    isLoading = _libraryItems.isEmpty;
    guardedNotifyListeners();
    if (autoStart && !_disposed) {
      _poller.start();
      await _poller.refresh();
    } else {
      isLoading = false;
    }
    guardedNotifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updatePolling();
  }

  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    _updatePolling();
  }

  void _updatePolling() {
    if (_visible &&
        _foreground &&
        (Settings.getValue<bool>(
              Constants.libraryForegroundUpdate,
              defaultValue: true,
            ) ??
            true)) {
      _poller.start();
    } else {
      _poller.pause();
    }
  }

  /// Offset pagination is documented by the official TorBox OpenAPI.
  Future<List<Map<String, dynamic>>> _allPages(
    Future<TorboxAPIResponse> Function(int offset, int limit) fetch,
  ) async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    final seen = <int>{};
    for (var offset = 0; ; offset += pageSize) {
      final response = await fetch(offset, pageSize);
      if (!response.success)
        throw StateError('TorBox no respondió correctamente.');
      final data = response.data;
      if (data == null) break;
      if (data is! List)
        throw const FormatException('Lista de TorBox no válida.');
      var added = 0;
      for (final raw in data) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = (row['id'] as num).toInt();
        if (seen.add(id)) {
          rows.add(row);
          added++;
        }
      }
      if (data.length < pageSize) break;
      // A server ignoring offset must not cause an infinite request loop.
      if (added == 0) throw StateError('La paginación de TorBox no avanzó.');
      if (_disposed || !_foreground)
        throw StateError('Actualización en pausa.');
      // Bound burst rate even for very large accounts (official: 300/min).
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return rows;
  }

  Future<void> refreshAll() {
    if (_disposed) return Future.value();
    return _refreshing ??= _refresh().whenComplete(() {
      _refreshing = null;
      guardedNotifyListeners();
    });
  }

  Future<void> _refresh() async {
    var failures = 0;
    Future<void> category<T extends LibraryItem>(
      Future<TorboxAPIResponse> Function(int, int) fetch,
      T Function(Map<String, dynamic>) parse,
    ) async {
      try {
        final rows = await _allPages(fetch);
        final fresh = rows.map(parse).toList();
        if (_disposed) return;
        // Save before replacing the snapshot; a failed write remains visible.
        await _cacheService.replaceType<T>(fresh);
        if (_disposed) return;
        _libraryItems.removeWhere((item) => item is T);
        _libraryItems.addAll(fresh);
      } on Object {
        failures++;
      }
    }

    await Future.wait([
      category<Torrent>(
        (o, l) =>
            apiService.getTorrentsList(bypassCache: true, offset: o, limit: l),
        Torrent.fromJson,
      ),
      category<WebDownload>(
        (o, l) => apiService.getWebDownloadsList(
          bypassCache: true,
          offset: o,
          limit: l,
        ),
        WebDownload.fromJson,
      ),
      category<Usenet>(
        (o, l) => apiService.getUsenetDownloadsList(
          bypassCache: true,
          offset: o,
          limit: l,
        ),
        Usenet.fromJson,
      ),
      category<QueuedTorrent>(
        (o, l) => apiService.getQueuedItemsList(
          bypassCache: true,
          offset: o,
          limit: l,
        ),
        QueuedTorrent.fromJson,
      ),
    ]);
    if (_disposed) return;
    _failedCycle = failures > 0;
    errorMessage = _failedCycle
        ? 'No se pudieron actualizar $failures categorías. Se conservan los datos anteriores; se reintentará automáticamente.'
        : null;
    if (!_failedCycle) lastUpdated = DateTime.now();
    isLoading = false;
    // Selection tracks identity, not obsolete instances from the prior poll.
    final keys = selectedItems.map((item) => item.identity).toSet();
    selectedItems = _libraryItems
        .where((item) => keys.contains(item.identity))
        .toList();
    isSelecting = selectedItems.isNotEmpty;
    guardedNotifyListeners();
  }

  LibraryItem? findItem(String identity) {
    for (final item in _libraryItems) {
      if (item.identity == identity) return item;
    }
    return null;
  }

  Future<void> resetForAccountChange() async {
    _poller.pause();
    await _refreshing;
    await _cacheService.clearCache();
    _libraryItems.clear();
    clearSelection();
    lastUpdated = null;
    if (apiService.hasApiKey) _updatePolling();
  }

  void guardedNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> isCacheNotEmpty() => _cacheService.isNotEmpty();
  Future<void> refreshTorrents({bool bypassCache = false}) => refreshAll();
  Future<void> refreshWebDownloads({bool bypassCache = false}) => refreshAll();
  Future<void> refreshUsenet({bool bypassCache = false}) => refreshAll();
  Future<Map<String, dynamic>> get torrentsFuture => _initFuture.then(
    (_) => {'success': !_failedCycle, 'detail': errorMessage},
  );
  Future<Map<String, dynamic>> get webDownloadsFuture => torrentsFuture;
  Future<Map<String, dynamic>> get usenetFuture => torrentsFuture;
  void onLibraryPageFirstView() {
    _firstView = true;
    unawaited(refreshAll());
  }

  bool get libraryPageFirstViewHasOccurred => _firstView;
  bool get isTorrentNamesCensored => _isTorrentNamesCensored;
  void toggleTorrentNamesCensoring() {
    _isTorrentNamesCensored = !_isTorrentNamesCensored;
    guardedNotifyListeners();
  }

  void startPeriodicUpdatesForActiveItems() => _updatePolling();
  void startPeriodicUpdate<T extends DownloadableItem>(int id) =>
      unawaited(refreshAll());
  void addQueuedTorrent(QueuedTorrent item) => unawaited(refreshAll());
  void addItemsToCache(List<LibraryItem> items) =>
      unawaited(_cacheService.saveItems(items));

  List<T> _ofType<T extends LibraryItem>() =>
      _libraryItems.whereType<T>().toList();
  List<Torrent> get activeTorrents =>
      _ofType<Torrent>().where((t) => t.active).toList();
  List<Torrent> get inactiveTorrents =>
      _ofType<Torrent>().where((t) => !t.active).toList();
  List<QueuedTorrent> get queuedTorrents => _ofType<QueuedTorrent>();
  List<WebDownload> get webDownloads => _ofType<WebDownload>();
  List<Usenet> get usenetDownloads => _ofType<Usenet>();
  String get selectedSortingOption => _selectedSortingOption;
  List<String> get selectedMainFilters =>
      List.unmodifiable(_selectedMainFilters);
  static String handleTorrentName(String name) {
    if (Settings.getValue<bool>(
          Constants.useTorrentNameParsing,
          defaultValue: false,
        ) ??
        false) {
      return parse(name)['title'] as String? ?? name;
    }
    return name;
  }

  static final Map<String, int Function(LibraryItem, LibraryItem)>
  sortingOptions = {
    'Default': (a, b) => 0,
    'A to Z': (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    'Z to A': (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
    'Largest': (a, b) => b.size.compareTo(a.size),
    'Smallest': (a, b) => a.size.compareTo(b.size),
    'Oldest': (a, b) => a.createdAt.compareTo(b.createdAt),
    'Newest': (a, b) => b.createdAt.compareTo(a.createdAt),
    'Recently updated': (a, b) => b.updatedAt.compareTo(a.updatedAt),
    'Progress': (a, b) => b.progress.compareTo(a.progress),
  };
  static final Map<String, bool Function(LibraryItem)> filters = {
    'Download Ready': (i) => i.downloadFinished,
    'Uploading': (i) => (i.uploadSpeed ?? 0) > 0 && i.active,
    'Downloading': (i) => i.active && !i.downloadFinished,
    'Cached': (i) => i is Torrent && i.cached,
  };
  List<T> _sortAndFilter<T extends LibraryItem>(List<T> items) {
    final result = items
        .where(
          (i) =>
              i.name.toLowerCase().contains(_searchQuery.toLowerCase()) &&
              _selectedMainFilters.every((f) => filters[f]?.call(i) ?? true),
        )
        .toList();
    result.sort(sortingOptions[_selectedSortingOption]);
    return result;
  }

  List<Torrent> get filteredSortedActiveTorrents =>
      _sortAndFilter(activeTorrents);
  List<Torrent> get filteredSortedInactiveTorrents =>
      _sortAndFilter(inactiveTorrents);
  List<QueuedTorrent> get filteredSortedQueuedTorrents =>
      _sortAndFilter(queuedTorrents);
  List<WebDownload> get filteredSortedWebDownloads =>
      _sortAndFilter(webDownloads);
  List<Usenet> get filteredSortedUsenetDownloads =>
      _sortAndFilter(usenetDownloads);
  void updateSortingOption(String option) {
    _selectedSortingOption = option;
    guardedNotifyListeners();
  }

  void updateFilter(String filter, bool selected) {
    _selectedMainFilters.remove(filter);
    if (selected) _selectedMainFilters.add(filter);
    guardedNotifyListeners();
  }

  void toggleSearch() {
    isSearching = !isSearching;
    guardedNotifyListeners();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    guardedNotifyListeners();
  }

  void startSelection(LibraryItem item) {
    selectedItems = [item];
    isSelecting = true;
    guardedNotifyListeners();
  }

  void toggleSelection(LibraryItem item) {
    if (selectedItems.any((i) => i.identity == item.identity)) {
      selectedItems.removeWhere((i) => i.identity == item.identity);
    } else {
      selectedItems.add(item);
    }
    isSelecting = selectedItems.isNotEmpty;
    guardedNotifyListeners();
  }

  void clearSelection() {
    selectedItems.clear();
    isSelecting = false;
    guardedNotifyListeners();
  }

  void selectAllItems() {
    selectedItems = List.of(_libraryItems);
    isSelecting = selectedItems.isNotEmpty;
    guardedNotifyListeners();
  }

  void invertSelection() {
    final keys = selectedItems.map((i) => i.identity).toSet();
    selectedItems = _libraryItems
        .where((i) => !keys.contains(i.identity))
        .toList();
    isSelecting = selectedItems.isNotEmpty;
    guardedNotifyListeners();
  }

  Future<void> _handleSelectedItems(
    Future<TorboxAPIResponse?> Function(LibraryItem) action, {
    bool delete = false,
  }) async {
    final successful = <LibraryItem>[];
    for (final item in List.of(selectedItems)) {
      if (_disposed) return;
      try {
        final response = await action(item);
        if (response?.success == true) {
          successful.add(item);
        } else if (response != null) {
          errorMessage =
              'No se pudo completar la operación sobre algunos elementos.';
        }
      } on Object {
        errorMessage =
            'Error de conexión. Los elementos afectados se conservan.';
      }
    }
    if (delete) {
      await _cacheService.deleteLibraryItems(successful);
      final keys = successful.map((i) => i.identity).toSet();
      _libraryItems.removeWhere((i) => keys.contains(i.identity));
    }
    clearSelection();
    await refreshAll();
  }

  Future<void> deleteSelectedItems() =>
      _handleSelectedItems((i) => i.delete(), delete: true);
  Future<void> stopSelectedItems() => _handleSelectedItems((i) => i.stop());
  Future<void> resumeSelectedItems() => _handleSelectedItems((i) => i.resume());
  Future<void> reannounceSelectedItems() =>
      _handleSelectedItems((i) => i.reannounce());
  Future<void> downloadSelectedItems() => _handleSelectedItems(
    (i) async => i is DownloadableItem ? i.download() : null,
  );

  @override
  void dispose() {
    _disposed = true;
    _poller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    apiService.clearDownloadsPageState(this);
    searchController.dispose();
    searchControllerFocusNode.dispose();
    super.dispose();
  }
}

enum DownloadableItemType { torrent, webdl, usenet }
