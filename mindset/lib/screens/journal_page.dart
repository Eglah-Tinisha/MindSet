import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/emotion_analyzer.dart';
import '../services/typing_behavior_analyzer.dart';
import '../services/voice_emotion_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/journal_widgets.dart';

enum ReflectionInput { text, voice }

class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.entries,
    required this.settings,
    this.entryToOpen,
    required this.entryOpenRequest,
    required this.resetRequest,
    required this.onEntrySaved,
    required this.onDeleteEntry,
    required this.onViewReports,
  });

  final List<JournalEntry> entries;
  final AppSettings settings;
  final JournalEntry? entryToOpen;
  final int entryOpenRequest;
  final int resetRequest;
  final Future<void> Function(JournalEntry entry) onEntrySaved;
  final Future<void> Function(String id) onDeleteEntry;
  final VoidCallback onViewReports;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final TextEditingController _controller = TextEditingController();
  ReflectionInput _input = ReflectionInput.text;
  EmotionResult? _result;
  EmotionResult? _textResult;
  TypingBehaviorResult? _typingResult;
  String? _typingFusionReason;
  final TypingBehaviorTracker _typingTracker = TypingBehaviorTracker();
  final TypingBehaviorAnalyzer _typingAnalyzer = TypingBehaviorAnalyzer();
  bool _isAnalyzing = false;
  bool _hasUnsavedResult = false;
  String? _errorMessage;
  bool _filtersExpanded = false;
  String? _emotionFilter;
  DateTimeRange? _dateFilter;
  final Set<String> _sourceFilters = <String>{};

  VoiceEmotionService? _voiceService;
  bool _isRecording = false;
  String? _recordingPath;
  String _voiceStatus =
      'Tap start, speak a short reflection, stop, then analyze.';
  String? _fusionNote;
  VoiceAnalysisOutcome? _voiceOutcome;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceEmotionService(apiBaseUrl: widget.settings.apiBaseUrl);
    _typingTracker.reset();
    _controller.addListener(_recordTypingEdit);
  }

  @override
  void dispose() {
    _controller.removeListener(_recordTypingEdit);
    _controller.dispose();
    _voiceService?.dispose();
    super.dispose();
  }

  void _recordTypingEdit() {
    if (_input == ReflectionInput.text && widget.settings.typingRhythm) {
      _typingTracker.recordText(_controller.text);
    }
  }

  @override
  void didUpdateWidget(covariant JournalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetRequest != oldWidget.resetRequest) {
      _newEntry();
    }

    final entry = widget.entryToOpen;
    if (entry != null &&
        widget.entryOpenRequest != oldWidget.entryOpenRequest) {
      _openEntry(entry);
    }
    if (!widget.settings.voiceReflection && _input == ReflectionInput.voice) {
      _input = ReflectionInput.text;
    }
    if (widget.settings.apiBaseUrl != oldWidget.settings.apiBaseUrl) {
      _voiceService?.dispose();
      _voiceService = VoiceEmotionService(
        apiBaseUrl: widget.settings.apiBaseUrl,
      );
    }
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _result = null;
        _errorMessage = 'Write a reflection first.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _fusionNote = null;
      _voiceOutcome = null;
    });

    try {
      final analyzer = EmotionAnalyzer(
        endpoint: Uri.parse(widget.settings.apiEndpoint),
      );
      final textResult = await analyzer.analyze(text);
      final typingResult = widget.settings.typingRhythm
          ? _typingAnalyzer.analyze(_typingTracker.snapshot())
          : null;
      final fusion = typingResult == null
          ? null
          : _typingAnalyzer.fuse(
              textResult: textResult,
              typingResult: typingResult,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _textResult = textResult;
        _typingResult = typingResult;
        _typingFusionReason = fusion?.reason;
        _result = fusion?.result ?? textResult;
        _hasUnsavedResult = true;
      });
      if (widget.settings.autoSaveEntries) {
        await _saveCurrent(showMessage: false);
      }
    } on EmotionAnalyzerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = null;
        _hasUnsavedResult = false;
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    final service = _voiceService;
    if (service == null || _isAnalyzing) {
      return;
    }

    try {
      if (_isRecording) {
        final path = await service.stopRecording();
        if (!mounted) {
          return;
        }
        setState(() {
          _isRecording = false;
          _recordingPath = path;
          _voiceStatus = path == null
              ? 'Recording stopped, but no audio file was saved.'
              : 'Recording saved. Tap Analyze voice.';
        });
      } else {
        await service.startRecording();
        if (!mounted) {
          return;
        }
        setState(() {
          _isRecording = true;
          _recordingPath = null;
          _result = null;
          _fusionNote = null;
          _voiceOutcome = null;
          _errorMessage = null;
          _voiceStatus = 'Recording... Speak naturally, then stop.';
        });
      }
    } on EmotionAnalyzerException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _errorMessage =
            'We could not analyze that recording. Check your microphone and try again.';
        _voiceStatus = 'We could not analyze that recording. Try again.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        _errorMessage = 'Microphone error: $error';
        _voiceStatus = 'Could not access the microphone.';
      });
    }
  }

  Future<void> _analyzeVoice() async {
    final service = _voiceService;
    final path = _recordingPath;
    if (service == null) {
      return;
    }
    if (path == null) {
      setState(() {
        _errorMessage = 'Record a short voice clip first.';
        _voiceStatus = 'Record a short voice clip first.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _voiceStatus = 'Analyzing your voice...';
    });

    try {
      final outcome = await service.analyzeRecording(path);
      if (!mounted) {
        return;
      }
      final hasTranscript = outcome.hasTranscript;
      final hasEmotion =
          outcome.result.label.toLowerCase() != 'unknown' &&
          outcome.result.confidencePercent > 0;
      final hasAnySignal =
          hasEmotion || outcome.hasAudioSignal || outcome.hasTextSignal;
      setState(() {
        _voiceOutcome = outcome;
        if (hasTranscript) {
          _controller.text = outcome.transcript;
        }
        _result = hasAnySignal ? outcome.result : null;
        _hasUnsavedResult = hasTranscript && hasEmotion;
        _fusionNote = outcome.provisionalReason;
        if (hasTranscript && hasAnySignal) {
          _voiceStatus = 'Your voice reflection is ready.';
        } else if (hasAnySignal) {
          _voiceStatus =
              'We could hear your voice, but not enough clear words were detected.';
          _hasUnsavedResult = false;
        } else {
          _voiceStatus =
              'We could not hear enough clear speech. Speak a little closer to the microphone and try again.';
          _errorMessage =
              'We could not hear enough clear speech. Check your microphone, speak for a few more seconds, and try again.';
          _voiceOutcome = null;
        }
      });
      if (widget.settings.autoSaveEntries && hasTranscript && hasEmotion) {
        await _saveCurrent(showMessage: false);
      }
    } on EmotionAnalyzerException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = null;
        _voiceOutcome = null;
        _hasUnsavedResult = false;
        _errorMessage = error.message;
        _voiceStatus = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = null;
        _voiceOutcome = null;
        _errorMessage =
            'We could not analyze that recording. Check your microphone and try again.';
        _voiceStatus = 'We could not analyze that recording. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<void> _saveCurrent({bool showMessage = true}) async {
    final result = _result;
    final text = _controller.text.trim();
    if (result == null || text.isEmpty) {
      setState(() => _errorMessage = 'Analyze a reflection before saving.');
      return;
    }

    final entry = JournalEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      text: text,
      result: result,
      textResult: _textResult,
      audioResult: _voiceOutcome?.audioResult,
      typingResult: _typingResult,
      fusionReason: _typingFusionReason,
      voiceReason: _voiceOutcome?.provisionalReason,
      voiceStrategy: _voiceOutcome?.strategy,
      voicePipeline: _voiceOutcome?.pipeline,
      voiceSttOk: _voiceOutcome?.sttOk,
      voiceSttMs: _voiceOutcome?.sttMs,
      voiceAudioMs: _voiceOutcome?.audioMs,
      voiceTextMs: _voiceOutcome?.textMs,
    );
    try {
      await widget.onEntrySaved(entry);
      if (!mounted) {
        return;
      }
      setState(() => _hasUnsavedResult = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = 'Could not save this journal: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this journal: $error')),
      );
      return;
    }

    if (showMessage && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Journal entry saved.')));
    }
  }

  void _openEntry(JournalEntry entry) {
    setState(() {
      _controller.text = entry.text;
      _result = entry.result;
      _textResult = entry.textResult;
      _input = entry.audioResult != null || entry.voiceStrategy != null
          ? ReflectionInput.voice
          : ReflectionInput.text;
      _typingResult = entry.typingResult;
      _typingFusionReason = entry.fusionReason;
      _hasUnsavedResult = false;
      _errorMessage = null;
      _fusionNote = null;
      _voiceOutcome = entry.audioResult != null || entry.voiceStrategy != null
          ? VoiceAnalysisOutcome(
              transcript: entry.text,
              result: entry.result!,
              textResult: entry.textResult,
              audioResult: entry.audioResult,
              provisionalReason: entry.voiceReason,
              strategy: entry.voiceStrategy,
              pipeline: entry.voicePipeline,
              sttOk: entry.voiceSttOk ?? true,
              sttMs: entry.voiceSttMs,
              audioMs: entry.voiceAudioMs,
              textMs: entry.voiceTextMs,
            )
          : null;
    });
  }

  void _newEntry() {
    setState(() {
      _controller.clear();
      _result = null;
      _textResult = null;
      _typingResult = null;
      _typingFusionReason = null;
      _typingTracker.reset();
      _hasUnsavedResult = false;
      _errorMessage = null;
      _fusionNote = null;
      _voiceOutcome = null;
      _recordingPath = null;
      _voiceStatus = 'Tap start, speak a short reflection, stop, then analyze.';
    });
  }

  List<JournalEntry> _filteredEntries() {
    return widget.entries.where((entry) {
      final emotionOk =
          _emotionFilter == null ||
          entry.displayMood.toLowerCase() == _emotionFilter!.toLowerCase();
      final created = entry.createdAt;
      final dateOk =
          _dateFilter == null ||
          (created != null &&
              !created.isBefore(_dateFilter!.start) &&
              !created.isAfter(_dateFilter!.end.add(const Duration(days: 1))));
      final sources = <String>{
        if (entry.textResult != null ||
            (entry.audioResult == null && entry.text.isNotEmpty))
          'text',
        if (entry.audioResult != null) 'voice',
        if (entry.typingResult != null) 'typing',
      };
      final sourceOk =
          _sourceFilters.isEmpty || _sourceFilters.any(sources.contains);
      return emotionOk && dateOk && sourceOk;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
    );
    if (range != null && mounted) {
      setState(() => _dateFilter = range);
    }
  }

  Future<void> _showSourceSelector() async {
    final selected = Set<String>.from(_sourceFilters);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('AI source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in const [
                ('text', 'Text AI'),
                ('voice', 'Voice AI'),
                ('typing', 'Typing pattern'),
              ])
                CheckboxListTile(
                  value: selected.contains(item.$1),
                  onChanged: (value) => setDialogState(() {
                    value == true
                        ? selected.add(item.$1)
                        : selected.remove(item.$1);
                  }),
                  title: Text(item.$2),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, <String>{}),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _sourceFilters
          ..clear()
          ..addAll(result);
      });
    }
  }

  String get _sourceFilterLabel {
    if (_sourceFilters.isEmpty) return 'All AI sources';
    return _sourceFilters
        .map(
          (source) => switch (source) {
            'text' => 'Text',
            'voice' => 'Voice',
            _ => 'Typing',
          },
        )
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final voiceEnabled = widget.settings.voiceReflection;
    final visibleEntries = _filteredEntries();
    return ScrollToTopOverlay(
      builder: (scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          PageTitle(
            title: 'Journal',
            subtitle:
                '${widget.entries.length} saved ${widget.entries.length == 1 ? 'reflection' : 'reflections'} in this app.',
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 18),
          SegmentedButton<ReflectionInput>(
            segments: const [
              ButtonSegment(
                value: ReflectionInput.text,
                icon: Icon(Icons.edit_note),
                label: Text('Text'),
              ),
              ButtonSegment(
                value: ReflectionInput.voice,
                icon: Icon(Icons.mic_none),
                label: Text('Voice'),
              ),
            ],
            selected: {_input},
            onSelectionChanged: (selection) {
              final value = selection.first;
              if (value == ReflectionInput.voice && !voiceEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Voice reflections are off in Settings.'),
                  ),
                );
                return;
              }
              setState(() => _input = value);
            },
          ),
          const SizedBox(height: 16),
          if (_input == ReflectionInput.text) ...[
            AppTextField(
              controller: _controller,
              label: 'Reflection',
              hint: 'What are you noticing today?',
              icon: Icons.notes_outlined,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isAnalyzing ? null : _analyze,
              icon: _isAnalyzing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze reflection'),
            ),
          ] else ...[
            VoiceRecorderCard(
              isRecording: _isRecording,
              isBusy: _isAnalyzing,
              transcript: _controller.text,
              statusMessage: _voiceStatus,
              onToggleRecording: _isAnalyzing ? null : _toggleRecording,
              onAnalyzeVoice: (_recordingPath == null || _isAnalyzing)
                  ? null
                  : _analyzeVoice,
            ),
            if (_controller.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              AppTextField(
                controller: _controller,
                label: 'Transcript (editable)',
                hint: 'You can edit the transcript before saving.',
                icon: Icons.notes_outlined,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ],
          const SizedBox(height: 18),
          if (_result != null) ...[
            if (_typingResult != null &&
                _textResult != null &&
                _voiceOutcome == null) ...[
              TypingTextBreakdownCard(
                typing: _typingResult!,
                text: _textResult!,
                fused: _result!,
                fusionReason:
                    _typingFusionReason ??
                    'Text result used because no fusion reason was available.',
              ),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Full fused details'),
            ],
            if (_voiceOutcome != null) ...[
              MultimodalBreakdownCard(
                combined: _voiceOutcome!.result,
                voice: _voiceOutcome!.audioResult,
                words: _voiceOutcome!.textResult,
                transcript: _voiceOutcome!.transcript,
                reason: _voiceOutcome!.provisionalReason,
                strategy: _voiceOutcome!.strategy,
                derivedState: _voiceOutcome!.derivedState,
                fusionSignals: _voiceOutcome!.fusionSignals,
              ),
              const SizedBox(height: 12),
              SectionHeader(title: 'Full combined details'),
            ],
            ReflectionResultCard(result: _result!),
            if (_fusionNote != null &&
                _fusionNote!.isNotEmpty &&
                _voiceOutcome == null) ...[
              const SizedBox(height: 10),
              WellnessCard(
                child: Text(
                  _fusionNote!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _hasUnsavedResult ? () => _saveCurrent() : null,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(_hasUnsavedResult ? 'Save this journal' : 'Saved'),
            ),
            const SizedBox(height: 12),
            PatternSummaryCard(
              entries: widget.entries,
              onViewReports: widget.onViewReports,
            ),
          ] else if (_errorMessage != null) ...[
            WellnessCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            WellnessCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconBox(icon: Icons.lock_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your analysis will appear here after you write or record a reflection.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Saved journals'),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
            icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.tune),
            label: Text(_filtersExpanded ? 'Hide filters' : 'Filter journals'),
          ),
          if (_filtersExpanded) ...[
            const SizedBox(height: 12),
            WellnessCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    key: ValueKey(_emotionFilter),
                    initialValue: _emotionFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Emotion',
                      prefixIcon: Icon(Icons.sentiment_satisfied_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All emotions'),
                      ),
                      for (final emotion
                          in widget.entries
                              .map((e) => e.displayMood)
                              .where((e) => e.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort())
                        DropdownMenuItem<String?>(
                          value: emotion,
                          child: Text(emotion),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _emotionFilter = value),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showSourceSelector,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(_sourceFilterLabel),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      _dateFilter == null
                          ? 'Choose date range'
                          : '${_dateFilter!.start.day}/${_dateFilter!.start.month}/${_dateFilter!.start.year} – ${_dateFilter!.end.day}/${_dateFilter!.end.month}/${_dateFilter!.end.year}',
                    ),
                  ),
                  if (_emotionFilter != null ||
                      _dateFilter != null ||
                      _sourceFilters.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _emotionFilter = null;
                          _dateFilter = null;
                          _sourceFilters.clear();
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _JournalSourceExplanationCard(),
          const SizedBox(height: 12),
          if (widget.entries.isEmpty)
            WellnessCard(
              child: Text(
                'Saved reflections will appear here so you can revisit the writing and emotion result later.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else if (visibleEntries.isEmpty)
            WellnessCard(
              child: Text(
                'No saved journals match these filters.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else
            for (final entry in visibleEntries) ...[
              _SavedEntryTile(
                entry: entry,
                onOpen: () => _openEntry(entry),
                onDelete: () async => widget.onDeleteEntry(entry.id),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _SavedEntryTile extends StatelessWidget {
  const _SavedEntryTile({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
  });

  final JournalEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return WellnessCard(
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onOpen,
              child: JournalEntryCard(entry: entry),
            ),
          ),
          IconButton(
            tooltip: 'Delete entry',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _JournalSourceExplanationCard extends StatefulWidget {
  const _JournalSourceExplanationCard();
  @override
  State<_JournalSourceExplanationCard> createState() =>
      _JournalSourceExplanationCardState();
}

class _JournalSourceExplanationCardState
    extends State<_JournalSourceExplanationCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => WellnessCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'What do these icons mean?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(_open ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 12),
          const _SourceLine(
            icon: Icons.text_fields_outlined,
            text: 'Text AI reads the words in your reflection.',
          ),
          const SizedBox(height: 8),
          const _SourceLine(
            icon: Icons.mic_none_outlined,
            text: 'Voice AI reads how your voice sounded.',
          ),
          const SizedBox(height: 8),
          const _SourceLine(
            icon: Icons.keyboard_alt_outlined,
            text: 'Typing pattern uses aggregate typing behaviour.',
          ),
        ],
      ],
    ),
  );
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}
