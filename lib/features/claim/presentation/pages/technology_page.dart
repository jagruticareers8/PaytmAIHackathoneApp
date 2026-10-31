import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/security/privacy_settings_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sathi_card.dart';
import '../../data/on_device_rag_service.dart';
import '../providers/claim_controller.dart';

class TechnologyPage extends StatefulWidget {
  const TechnologyPage({super.key});

  @override
  State<TechnologyPage> createState() => _TechnologyPageState();
}

class _TechnologyPageState extends State<TechnologyPage> {
  final _privacyStore = PrivacySettingsStore();
  final _localRag = SathiOnDeviceRagService();
  bool _checkingLocalModels = true;
  bool _installingLocalModels = false;
  bool _localModelsReady = false;
  int _modelDownloadProgress = 0;
  String _modelDownloadLabel = '';
  bool _consentLoading = true;
  bool _allowCloudConsent = false;
  bool _allowVoiceConsent = false;
  bool _savingConsent = false;
  bool _savingVoiceConsent = false;
  static const _apiBaseUrl = String.fromEnvironment(
    'SATHI_API_BASE_URL',
    defaultValue: '',
  );
  bool get _backendConfigured => _apiBaseUrl.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadConsent();
    _checkLocalModels();
  }

  Future<void> _checkLocalModels() async {
    try {
      final ready = await _localRag.modelsReady;
      if (!mounted) return;
      setState(() {
        _localModelsReady = ready;
        _checkingLocalModels = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localModelsReady = false;
        _checkingLocalModels = false;
      });
    }
  }

  Future<void> _installLocalModels() async {
    setState(() {
      _installingLocalModels = true;
      _modelDownloadProgress = 0;
      _modelDownloadLabel = 'Preparing on-device AI';
    });
    try {
      await _localRag.installModels(
        onProgress: (label, progress) {
          if (!mounted) return;
          setState(() {
            _modelDownloadLabel = label;
            _modelDownloadProgress = progress.clamp(0, 100).round();
          });
        },
      );
      final ready = await _localRag.modelsReady;
      if (!mounted) return;
      setState(() => _localModelsReady = ready);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ready
                ? 'Offline AI is ready. Sathi can now retrieve and generate answers on this device.'
                : 'The model download completed, but the runtime did not confirm both models. Please retry.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not install offline AI. Check your internet connection and device storage, then retry.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _installingLocalModels = false;
          _checkingLocalModels = false;
        });
      }
    }
  }

  Future<void> _loadConsent() async {
    try {
      final values = await Future.wait<bool>([
        _privacyStore.readCloudConsent(),
        _privacyStore.readVoiceConsent(),
      ]);
      if (!mounted) return;
      setState(() {
        _allowCloudConsent = values[0];
        _allowVoiceConsent = values[1];
        _consentLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _consentLoading = false);
    }
  }

  Future<void> _saveConsent(bool value) async {
    setState(() {
      _savingConsent = true;
      _allowCloudConsent = value;
    });
    try {
      await _privacyStore.writeCloudConsent(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? (_backendConfigured
                ? 'Online general-information lookup enabled. Sathi still checks local data first and asks before each online question.'
                : 'Preference saved, but no backend URL is configured. Live AI will return a connection error until configured.')
                : 'Online lookup switched off. Sathi will stay on-device.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _allowCloudConsent = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save privacy preference: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingConsent = false);
    }
  }

  Future<void> _saveVoiceConsent(bool value) async {
    setState(() {
      _savingVoiceConsent = true;
      _allowVoiceConsent = value;
    });
    try {
      await _privacyStore.writeVoiceConsent(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? (_backendConfigured
                ? 'Cloud voice enabled for General information mode. Sathi asks before every recording upload; Private mode stays device-only.'
                : 'Preference saved, but no backend URL is configured. Device speech will be used instead.')
                : 'Cloud voice transcription switched off. Device speech will be used instead.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _allowVoiceConsent = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save voice preference: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingVoiceConsent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How Sathi works')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'TECHNOLOGY AND PRIVACY',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.teal,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Local-first. Online only when you choose.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'You do not need to understand AI to use Sathi. Add your document, check the highlighted text, read the explanation, and choose the next step yourself.',
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          const _StackLayer(
            title: 'Client app',
            icon: Icons.phone_android_rounded,
            subtitle: 'What you use',
            chips: [
              'Flutter',
              'Dart',
              'Platform Channels',
              'BLoC',
              'Secure storage',
            ],
            note:
            'The app screens and state use Flutter + BLoC. Claim text, drafts, timeline and app-copied documents are encrypted with AES-GCM in app-private storage; the encryption key is held in Android Keystore/iOS Keychain through secure storage.',
            active: {'Flutter', 'Dart', 'BLoC', 'Secure storage'},
          ),
          const SizedBox(height: 12),
          _StackLayer(
            title: 'Local processing',
            icon: Icons.memory_rounded,
            subtitle: 'Private work that stays on your phone',
            chips: const [
              'AES-GCM encrypted vault',
              'On-device RAG',
              'Qwen3 0.6B',
              'EmbeddingGemma 2',
              'On-device OCR',
              'Device speech',
            ],
            note:
            'The app stores copied attachments, PII-masked OCR text, drafts and activity notes in an AES-GCM encrypted app-private vault. After downloading the optional Qwen3 0.6B language model and EmbeddingGemma 2 embedding model, Sathi can retrieve relevant local passages and generate grounded answers entirely on the device. Sathi reads digital PDFs, scanned PDFs and supported photos on this phone. Scanned pages are processed with on-device OCR. Device speech depends on Android/iOS speech-service settings. The model download itself needs internet once; inference and retrieval then run locally. Teal chips are available now; the two models and local RAG are highlighted only after both models are installed.',
            active: {
              'AES-GCM encrypted vault',
              'On-device OCR',
              'Device speech',
              if (_localModelsReady) ...{
                'On-device RAG',
                'Qwen3 0.6B',
                'EmbeddingGemma 2',
              },
            },
          ),
          const SizedBox(height: 12),
          const _StackLayer(
            title: 'Optional online information',
            icon: Icons.cloud_outlined,
            subtitle: 'Only for a general question after local lookup',
            chips: [
              'Gemini API',
              'Question confirmation',
              'No files attached',
              'No chat history',
              'No claim context',
            ],
            note:
            'When the on-device models are installed, the app embeds local document chunks, retrieves semantically relevant passages, and generates an answer in the local Qwen model. OCR text, local embeddings and claim context remain encrypted and on-device. If the local model cannot find relevant evidence, personal/claim-specific questions stay local-only. Only a separate general-information question can be sent to Gemini after consent and per-question confirmation; the online request contains only that question. Insurer status APIs are not connected.',
            active: {
              'Gemini API',
              'Question confirmation',
              'No files attached',
              'No chat history',
              'No claim context',
            },
          ),
          const SizedBox(height: 12),
          const _StackLayer(
            title: 'Platform',
            icon: Icons.hub_outlined,
            subtitle: 'Connect to insurer systems safely',
            chips: [
              'REST + WebSocket',
              'Firebase',
              'Partner APIs',
              'Analytics',
              'CI/CD',
            ],
            note:
            'A REST adapter and WebSocket example are supplied. Firebase and partner APIs need project credentials, sandbox access, consent rules and server-side authorisation. A GitHub Actions workflow is included.',
            active: {'REST + WebSocket', 'CI/CD'},
          ),
          const SizedBox(height: 14),
          SathiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.offline_bolt_rounded, color: AppColors.teal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Install private on-device AI',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Download two model files once (about 500 MB total, plus extra free storage). Qwen3 generates answers and EmbeddingGemma finds the most relevant passages in your saved documents. After installation, local retrieval and generation do not need Gemini or the internet. Your private claim text and embeddings remain in the encrypted local vault.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _checkingLocalModels
                      ? 'Checking installed model files…'
                      : _localModelsReady
                      ? 'Status: both on-device models are installed'
                      : 'Status: on-device models are not installed',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_installingLocalModels) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _modelDownloadProgress / 100),
                  const SizedBox(height: 5),
                  Text(
                    '$_modelDownloadLabel · $_modelDownloadProgress%',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed:
                  (_checkingLocalModels ||
                      _installingLocalModels ||
                      _localModelsReady)
                      ? null
                      : _installLocalModels,
                  icon: Icon(
                    _localModelsReady
                        ? Icons.check_circle_outline
                        : Icons.download_rounded,
                  ),
                  label: Text(
                    _localModelsReady
                        ? 'Offline AI ready'
                        : _installingLocalModels
                        ? 'Downloading models…'
                        : 'Download offline AI models',
                  ),
                ),
                if (_localModelsReady)
                  TextButton.icon(
                    onPressed: _checkLocalModels,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Recheck model status'),
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Device requirements: Android 11 / API 30 or later on arm64-v8a, or iOS 15.5 or later, plus enough free memory and storage. Some x86_64 emulators cannot run the local model. On iOS, the largest models may also need Apple-approved memory entitlements and matching signing. If installation is unsupported, local text search and the offline FAQ remain available.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The compact local model may be less capable than cloud Gemini. Sathi should cite retrieved local evidence and say when the saved text does not answer a question. This is not an insurer connection.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SathiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.teal),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your privacy choice',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _backendConfigured
                      ? 'This switch allows optional online lookup for a general-information question only. Sathi searches local data first and asks you to confirm the exact question before sending it. Only that question is sent to Gemini—no attachments, OCR text, claim details or chat history. Personal and claim-specific questions stay local even when this switch is on.'
                      : 'A backend URL is not configured. Turning this on stores your preference only. Online general information also requires SATHI_API_BASE_URL, a running backend and a valid backend API key.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                if (_consentLoading)
                  const LinearProgressIndicator()
                else
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Allow online general-information lookup',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _allowCloudConsent
                          ? (_backendConfigured
                          ? 'On · backend URL set; Gemini key required server-side'
                          : 'On · no backend URL; live answers unavailable')
                          : 'Off · cloud AI is disabled',
                    ),
                    value: _allowCloudConsent,
                    onChanged: _savingConsent ? null : _saveConsent,
                  ),
                if (_savingConsent) const LinearProgressIndicator(),
                const Divider(height: 24),
                const Text(
                  'AI Hinglish voice transcription',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Voice transcription is a separate, optional cloud feature. It is used only in General information mode, and Sathi shows a confirmation before each recording is uploaded for transcription. The audio itself leaves the device; never use this for names, diagnoses, policy/claim numbers, bills or private case details. In Private files mode, Sathi does not upload audio. Device speech recognition behaviour still depends on Android/iOS speech-service settings.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                if (_consentLoading)
                  const LinearProgressIndicator()
                else
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Allow optional cloud voice transcription',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _allowVoiceConsent
                          ? (_backendConfigured
                          ? 'On · requires online-information consent too, General information mode, and a confirmation for each recording'
                          : 'On · no backend URL, device speech will be used')
                          : 'Off · microphone uses device speech recognition',
                    ),
                    value: _allowVoiceConsent,
                    onChanged: _savingVoiceConsent ? null : _saveVoiceConsent,
                  ),
                if (_savingVoiceConsent) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Backend status: ${_backendConfigured ? _apiBaseUrl : 'not configured'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Easy-to-follow journey',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 10),
          const _StepLine(
            number: '1',
            title: 'Add a document',
            description: 'Choose a PDF or photo from your phone.',
          ),
          const _StepLine(
            number: '2',
            title: 'Read and check',
            description:
            'Sathi reads your PDF or photo automatically on this phone. Common identifiers are masked before the text is saved.',
          ),
          const _StepLine(
            number: '3',
            title: 'Understand the reason',
            description:
            'Sathi reads encrypted local documents and checks the offline guide first. For a general question only, online lookup requires consent and a confirmation showing exactly what will be sent. No files, OCR, claim context or chat history are attached. Verified policy retrieval and insurer status APIs are not yet connected.',
          ),
          const _StepLine(
            number: '4',
            title: 'Review the next step',
            description:
            'Edit your draft, submit it through the insurer’s official channel, then record your progress.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _consentLoading
                ? null
                : () => _confirmClearLocalData(context),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete all Sathi local data'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
          ),
          const SizedBox(height: 8),
          const Text(
            'This deletes Sathi’s encrypted app copies, saved OCR text, drafts, and local activity. It does not delete the original files in Photos or Downloads.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Sathi'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearLocalData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all local Sathi data?'),
        content: const Text(
          'This permanently removes Sathi’s encrypted copies of documents, saved OCR text, drafts and local activity from this app on this device. It does not affect the original files in Photos/Downloads. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete local data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<ClaimCubit>().clearAllLocalData();
      await _privacyStore.writeCloudConsent(false);
      await _privacyStore.writeVoiceConsent(false);
      if (!mounted) return;
      setState(() {
        _allowCloudConsent = false;
        _allowVoiceConsent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sathi local data and online-consent settings were cleared.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not clear all local data. Check device storage and try again.',
          ),
        ),
      );
    }
  }
}

class _StackLayer extends StatelessWidget {
  const _StackLayer({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.chips,
    required this.note,
    required this.active,
  });

  final String title;
  final IconData icon;
  final String subtitle;
  final List<String> chips;
  final String note;
  final Set<String> active;

  @override
  Widget build(BuildContext context) {
    return SathiCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.teal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chips
                .map(
                  (chip) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: active.contains(chip)
                      ? AppColors.mint
                      : const Color(0xFFF1EBDD),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active.contains(chip)
                        ? AppColors.tealDark
                        : AppColors.navy,
                  ),
                ),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({
    required this.number,
    required this.title,
    required this.description,
  });
  final String number;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.tealDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.45,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
