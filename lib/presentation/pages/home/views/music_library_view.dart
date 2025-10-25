part of 'package:misuzu_music/presentation/pages/home_page.dart';

class MusicLibraryView extends StatefulWidget {
  const MusicLibraryView({
    super.key,
    this.onAddToPlaylist,
    this.onDetailStateChanged,
  });

  final ValueChanged<Track>? onAddToPlaylist;
  final ValueChanged<bool>? onDetailStateChanged;

  @override
  State<MusicLibraryView> createState() => _MusicLibraryViewState();
}

class _MusicLibraryViewState extends State<MusicLibraryView> {
  bool _showList = false;
  String? _activeFilterKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _notifyDetailState();
      }
    });
  }

  bool get canNavigateBack => _showList;

  void exitToOverview() {
    if (!_showList) {
      return;
    }
    setState(() {
      _showList = false;
      _activeFilterKey = null;
    });
    _notifyDetailState();
  }

  void _notifyDetailState() {
    widget.onDetailStateChanged?.call(_showList);
  }

  bool _hasArtwork(Track track) {
    final artworkPath = track.artworkPath;
    if (artworkPath == null || artworkPath.isEmpty) {
      return false;
    }
    try {
      return File(artworkPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  Track? _findPreviewTrack(List<Track> tracks) {
    if (tracks.isEmpty) {
      return null;
    }
    final withArtwork = tracks.where(_hasArtwork).toList();
    if (withArtwork.isEmpty) {
      return tracks.first;
    }

    if (withArtwork.length == 1) {
      return withArtwork.first;
    }

    withArtwork.sort((a, b) {
      final at = (a.title).toLowerCase();
      final bt = (b.title).toLowerCase();
      final titleCompare = at.compareTo(bt);
      if (titleCompare != 0) {
        return titleCompare;
      }
      final aa = (a.artist).toLowerCase();
      final ba = (b.artist).toLowerCase();
      final artistCompare = aa.compareTo(ba);
      if (artistCompare != 0) {
        return artistCompare;
      }
      final al = (a.album).toLowerCase();
      final bl = (b.album).toLowerCase();
      final albumCompare = al.compareTo(bl);
      if (albumCompare != 0) {
        return albumCompare;
      }
      return a.filePath.compareTo(b.filePath);
    });
    return withArtwork[withArtwork.length ~/ 2];
  }

  bool _isTrackInDirectory(Track track, String directoryPath) {
    if (track.sourceType != TrackSourceType.local) {
      return false;
    }
    final normalizedDirectory = p.normalize(directoryPath);
    final trackPath = p.normalize(track.filePath);
    if (trackPath == normalizedDirectory) {
      return true;
    }
    return p.isWithin(normalizedDirectory, trackPath);
  }

  List<_DirectorySummaryData> _buildLibrarySummariesData(
    MusicLibraryLoaded state,
  ) {
    final localSummaries = <_DirectorySummaryData>[];
    final localTracks = state.tracks
        .where((track) => track.sourceType == TrackSourceType.local)
        .toList();

    final normalizedDirectories = <String>{
      ...state.libraryDirectories.map((dir) => p.normalize(dir)),
    };

    if (normalizedDirectories.isEmpty) {
      normalizedDirectories.addAll(
        localTracks.map(
          (track) => p.normalize(File(track.filePath).parent.path),
        ),
      );
    }

    for (final directory in normalizedDirectories) {
      final normalizedDirectory = directory;
      final directoryTracks = localTracks
          .where((track) => _isTrackInDirectory(track, normalizedDirectory))
          .toList();

      if (directoryTracks.isEmpty) {
        continue;
      }

      final previewTrack = _findPreviewTrack(directoryTracks);
      final hasArtwork = previewTrack != null && _hasArtwork(previewTrack);
      final displayName = normalizedDirectory.isEmpty
          ? '全部歌曲'
          : p.basename(normalizedDirectory);

      localSummaries.add(
        _DirectorySummaryData(
          filterKey: normalizedDirectory,
          displayName: displayName,
          directoryPath: normalizedDirectory,
          previewTrack: previewTrack,
          totalTracks: directoryTracks.length,
          hasArtwork: hasArtwork,
        ),
      );
    }

    final remoteSummaries = <_DirectorySummaryData>[];
    for (final source in state.webDavSources) {
      final remoteTracks = state.tracks
          .where(
            (track) =>
                track.sourceType == TrackSourceType.webdav &&
                track.sourceId == source.id,
          )
          .toList();
      if (remoteTracks.isEmpty) {
        continue;
      }

      final previewTrack = _findPreviewTrack(remoteTracks);
      final hasArtwork = previewTrack != null && _hasArtwork(previewTrack);
      remoteSummaries.add(
        _DirectorySummaryData(
          filterKey: 'webdav://${source.id}',
          displayName: source.name,
          directoryPath: source.rootPath,
          webDavSource: source,
          previewTrack: previewTrack,
          totalTracks: remoteTracks.length,
          hasArtwork: hasArtwork,
        ),
      );
    }

    final Map<String, List<Track>> mysteryGroups = {};
    final Map<String, String> mysteryDisplayNames = {};
    final Map<String, String?> mysteryCodes = {};

    for (final track in state.tracks) {
      if (track.sourceType != TrackSourceType.mystery) {
        continue;
      }
      final sourceId = track.sourceId;
      if (sourceId == null || sourceId.isEmpty) {
        continue;
      }
      final headers = track.httpHeaders;
      mysteryGroups.putIfAbsent(sourceId, () => <Track>[]).add(track);
      if (!mysteryDisplayNames.containsKey(sourceId)) {
        final code = headers?[MysteryLibraryConstants.headerCode];
        final displayName = headers?[MysteryLibraryConstants.headerDisplayName] ??
            (code != null && code.isNotEmpty
                ? '神秘代码 $code'
                : '神秘音乐库');
        mysteryDisplayNames[sourceId] = displayName;
        mysteryCodes[sourceId] = code;
      }
    }

    mysteryGroups.forEach((sourceId, tracks) {
      if (tracks.isEmpty) {
        return;
      }
      final previewTrack = _findPreviewTrack(tracks);
      final hasArtwork = previewTrack != null && _hasArtwork(previewTrack);
      remoteSummaries.add(
        _DirectorySummaryData(
          filterKey: 'mystery://$sourceId',
          displayName: mysteryDisplayNames[sourceId] ?? '神秘音乐库',
          previewTrack: previewTrack,
          totalTracks: tracks.length,
          hasArtwork: hasArtwork,
          mysterySourceId: sourceId,
          mysteryDisplayName: mysteryDisplayNames[sourceId],
          mysteryCode: mysteryCodes[sourceId],
        ),
      );
    });

    final allPreviewTrack = _findPreviewTrack(state.tracks);
    final allHasArtwork =
        allPreviewTrack != null && _hasArtwork(allPreviewTrack);
    final allSummary = _DirectorySummaryData(
      filterKey: _DirectorySummaryData.allKey,
      displayName: '全部歌曲',
      directoryPath: null,
      previewTrack: allPreviewTrack,
      totalTracks: state.tracks.length,
      hasArtwork: allHasArtwork,
    );

    final filteredLocalSummaries =
        localSummaries.length == 1 &&
            localSummaries.first.totalTracks == allSummary.totalTracks
        ? <_DirectorySummaryData>[]
        : List<_DirectorySummaryData>.from(localSummaries);

    final summaries = [...filteredLocalSummaries, ...remoteSummaries];

    summaries.sort((a, b) {
      if (a.isRemote != b.isRemote) {
        return a.isRemote ? 1 : -1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    if (summaries.isEmpty) {
      summaries.add(allSummary);
    } else {
      summaries.insert(0, allSummary);
    }

    return summaries;
  }

  Future<void> _confirmRemoveSummary(_DirectorySummaryData summary) async {
    if (summary.isAll) {
      return;
    }

    final isRemote = summary.isRemote;
    final isWebDav = summary.isWebDav;
    final isMystery = summary.isMystery;
    final name = summary.displayName;
    final title = isWebDav
        ? '移除 WebDAV 音乐库'
        : isMystery
            ? '卸载神秘音乐库'
            : '移除音乐文件夹';
    final message = isWebDav
        ? '确定要移除 "$name" 吗？移除后将不再同步该 WebDAV 源的歌曲。'
        : isMystery
            ? '确定要卸载 "$name" 吗？卸载后将移除该神秘代码导入的所有歌曲。'
            : '确定要移除 "$name" 目录吗？这将从音乐库中移除该目录中的所有歌曲。';

    bool? confirmed;
    if (prefersMacLikeUi()) {
      confirmed = await showMacosAlertDialog<bool>(
        context: context,
        builder: (context) => MacosAlertDialog(
          appIcon: const MacosIcon(CupertinoIcons.exclamationmark_triangle),
          title: Text(title),
          message: Text(message),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('移除'),
          ),
          secondaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('移除'),
            ),
          ],
        ),
      );
    }

    if (confirmed != true) {
      return;
    }

    final bloc = context.read<MusicLibraryBloc>();
    if (isWebDav && summary.webDavSource != null) {
      bloc.add(RemoveWebDavSourceEvent(summary.webDavSource!));
    } else if (isMystery && summary.mysterySourceId != null) {
      bloc.add(UnmountMysteryLibraryEvent(summary.mysterySourceId!));
    } else if (summary.directoryPath != null) {
      bloc.add(RemoveLibraryDirectoryEvent(summary.directoryPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MusicLibraryBloc, MusicLibraryState>(
      builder: (context, state) {
        if (state is MusicLibraryLoading || state is MusicLibraryScanning) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProgressCircle(),
                SizedBox(height: 16),
                Text('正在加载音乐库...'),
              ],
            ),
          );
        }

        if (state is MusicLibraryError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MacosIcon(
                  CupertinoIcons.exclamationmark_triangle,
                  size: 64,
                  color: CupertinoColors.systemRed,
                ),
                const SizedBox(height: 16),
                Text('加载失败', style: MacosTheme.of(context).typography.title1),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  textAlign: TextAlign.center,
                  style: MacosTheme.of(context).typography.body.copyWith(
                    color: MacosColors.systemGrayColor,
                  ),
                ),
                const SizedBox(height: 16),
                PushButton(
                  controlSize: ControlSize.large,
                  onPressed: () {
                    context.read<MusicLibraryBloc>().add(const LoadAllTracks());
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (state is MusicLibraryLoaded) {
          if (state.tracks.isEmpty) {
            return _PlaylistMessage(
              icon: CupertinoIcons.music_albums,
              message: '音乐库为空',
            );
          }

          final summariesData = _buildLibrarySummariesData(state);
          final filterKeys = summariesData
              .map((summary) => summary.filterKey)
              .toSet();
          if (_activeFilterKey != null &&
              !filterKeys.contains(_activeFilterKey)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _activeFilterKey = null;
                _showList = false;
              });
              _notifyDetailState();
            });
          }

          final hasActiveSearch =
              state.searchQuery != null && state.searchQuery!.trim().isNotEmpty;
          if (hasActiveSearch && !_showList) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _showList = true);
              _notifyDetailState();
            });
          }
          if (hasActiveSearch && _activeFilterKey != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _activeFilterKey = null;
              });
            });
          }

          if (!_showList) {
            return CollectionOverviewGrid(
              itemCount: summariesData.length,
              itemBuilder: (context, tileWidth, index) {
                final summary = summariesData[index];
                final subtitle = summary.isWebDav
                    ? '${summary.webDavSource!.baseUrl}${summary.webDavSource!.rootPath}'
                    : summary.isMystery
                        ? '神秘代码: ${summary.mysteryCode ?? summary.displayName}'
                        : (summary.directoryPath == null ||
                                summary.directoryPath!.isEmpty
                            ? '所有目录'
                            : p.normalize(summary.directoryPath!));
                final gradient = summary.isRemote
                    ? [const Color(0xFF2F3542), const Color(0xFF1E272E)]
                    : null;

                final remoteArtworkUrl =
                    MysteryLibraryConstants.buildArtworkUrl(
                  summary.previewTrack?.httpHeaders,
                  thumbnail: true,
                );

                return CollectionSummaryCard(
                  title: summary.displayName,
                  subtitle: subtitle,
                  detailText: '${summary.totalTracks} 首歌曲 · 点击查看全部',
                  artworkPath: summary.previewTrack?.artworkPath,
                  remoteImageUrl: remoteArtworkUrl,
                  hasArtwork: summary.hasArtwork,
                  fallbackIcon: summary.isWebDav
                      ? CupertinoIcons.cloud
                      : summary.isMystery
                          ? CupertinoIcons.music_note
                          : CupertinoIcons.folder_solid,
                  gradientColors: gradient,
                  onTap: () {
                    setState(() {
                      _showList = true;
                      _activeFilterKey = summary.isAll
                          ? null
                          : summary.filterKey;
                    });
                    _notifyDetailState();
                  },
                  onRemove: summary.isAll
                      ? null
                      : () => _confirmRemoveSummary(summary),
                  contextMenuLabel: summary.isAll
                      ? null
                      : (summary.isWebDav
                          ? '移除 WebDAV 音乐库'
                          : summary.isMystery
                              ? '卸载神秘音乐库'
                              : '移除音乐库'),
                );
              },
            );
          }

          final filteredTracks = _activeFilterKey == null
              ? state.tracks
              : state.tracks.where((track) {
                  final key = _activeFilterKey!;
                  if (_DirectorySummaryData.isAllKey(key)) {
                    return true;
                  }
                  if (key.startsWith('webdav://')) {
                    final sourceId = key.substring('webdav://'.length);
                    return track.sourceType == TrackSourceType.webdav &&
                        track.sourceId == sourceId;
                  }
                  if (key.startsWith('mystery://')) {
                    final sourceId = key.substring('mystery://'.length);
                    return track.sourceType == TrackSourceType.mystery &&
                        track.sourceId == sourceId;
                  }
                  return _isTrackInDirectory(track, key);
                }).toList();

          final listWidget = MacOSTrackListView(
            tracks: filteredTracks,
            onAddToPlaylist: widget.onAddToPlaylist,
          );

          if (_activeFilterKey != null) {
            return Shortcuts(
              shortcuts: <LogicalKeySet, Intent>{
                LogicalKeySet(LogicalKeyboardKey.escape):
                    const _ExitLibraryOverviewIntent(),
              },
              child: Actions(
                actions: {
                  _ExitLibraryOverviewIntent:
                      CallbackAction<_ExitLibraryOverviewIntent>(
                        onInvoke: (intent) {
                          setState(() {
                            _showList = false;
                            _activeFilterKey = null;
                          });
                          _notifyDetailState();
                          return null;
                        },
                      ),
                },
                child: Focus(autofocus: true, child: listWidget),
              ),
            );
          }

          return listWidget;
        }

        return _PlaylistMessage(
          icon: CupertinoIcons.music_albums,
          message: '音乐库为空',
        );
      },
    );
  }
}

class _ExitLibraryOverviewIntent extends Intent {
  const _ExitLibraryOverviewIntent();
}

class _DirectorySummaryData {
  const _DirectorySummaryData({
    required this.filterKey,
    required this.displayName,
    required this.previewTrack,
    required this.totalTracks,
    required this.hasArtwork,
    this.directoryPath,
    this.webDavSource,
    this.mysterySourceId,
    this.mysteryDisplayName,
    this.mysteryCode,
  });

  final String filterKey;
  final String displayName;
  final Track? previewTrack;
  final int totalTracks;
  final bool hasArtwork;
  final String? directoryPath;
  final WebDavSource? webDavSource;
  final String? mysterySourceId;
  final String? mysteryDisplayName;
  final String? mysteryCode;

  bool get isWebDav => webDavSource != null;
  bool get isMystery => mysterySourceId != null;
  bool get isRemote => isWebDav || isMystery;
  bool get isAll => filterKey == allKey;

  static const String allKey = '__all__';
  static bool isAllKey(String key) => key == allKey;
}
