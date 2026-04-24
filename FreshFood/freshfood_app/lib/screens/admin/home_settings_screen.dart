import 'package:flutter/material.dart';
import 'package:freshfood_app/api/api_client.dart';
import 'package:freshfood_app/config/api_config.dart';
import 'package:freshfood_app/models/home_settings.dart';
import 'package:freshfood_app/state/auth_state.dart';
import 'package:image_picker/image_picker.dart';

class HomeSettingsScreen extends StatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  State<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends State<HomeSettingsScreen> {
  final _api = ApiClient();
  final _picker = ImagePicker();
  bool _loading = true;
  bool _saving = false;
  String? _uploadingKey;
  String? _err;
  HomePageSettings? _data; // persisted
  HomePageSettings? _edit; // draft
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final existing = await _api.getAdminHomePageSettings();
      final fallback = await _api.getHomePageSettings();
      final x = existing ?? fallback;
      if (!mounted) return;
      setState(() {
        _data = x;
        _edit = x;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  HomePageSettings _ensureDraft() => _edit ?? const HomePageSettings();

  List<HomeSeasonalCard> _seasonalCards(HomePageSettings d) {
    final raw = d.seasonal?.cards ?? const <HomeSeasonalCard>[];
    final cards = raw.take(3).toList(growable: true);
    while (cards.length < 3) {
      cards.add(const HomeSeasonalCard(title: '', imageUrl: ''));
    }
    return cards;
  }

  String _resolveMediaUrl(String url) {
    return ApiConfig.resolveMediaUrl(url);
  }

  void _setHero(String k, String v) {
    final d = _ensureDraft();
    final h = d.hero ?? const HomeHeroSettings();
    HomeHeroSettings next;
    switch (k) {
      case 'eyebrow':
        next = HomeHeroSettings(
          eyebrow: v,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'title':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: v,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'highlight':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: v,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'subtitle':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: v,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'imageUrl':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: v,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'primaryCtaText':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: v,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'primaryCtaHref':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: v,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'secondaryCtaText':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: v,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'secondaryCtaHref':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: v,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'feature1Title':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: v,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'feature1Sub':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: v,
          feature2Title: h.feature2Title,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'feature2Title':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: v,
          feature2Sub: h.feature2Sub,
        );
        break;
      case 'feature2Sub':
        next = HomeHeroSettings(
          eyebrow: h.eyebrow,
          title: h.title,
          highlight: h.highlight,
          subtitle: h.subtitle,
          primaryCtaText: h.primaryCtaText,
          primaryCtaHref: h.primaryCtaHref,
          secondaryCtaText: h.secondaryCtaText,
          secondaryCtaHref: h.secondaryCtaHref,
          imageUrl: h.imageUrl,
          feature1Title: h.feature1Title,
          feature1Sub: h.feature1Sub,
          feature2Title: h.feature2Title,
          feature2Sub: v,
        );
        break;
      default:
        return;
    }
    setState(() {
      _edit = HomePageSettings(hero: next, roots: d.roots, seasonal: d.seasonal);
      _dirty = true;
    });
  }

  void _setRoots(String k, String v) {
    final d = _ensureDraft();
    final r = d.roots ?? const HomeRootsSettings();
    HomeRootsSettings next;
    switch (k) {
      case 'subheading':
        next = HomeRootsSettings(
          subheading: v,
          title: r.title,
          paragraph1: r.paragraph1,
          paragraph2: r.paragraph2,
          imageUrl: r.imageUrl,
          stat1Value: r.stat1Value,
          stat1Label: r.stat1Label,
          stat2Value: r.stat2Value,
          stat2Label: r.stat2Label,
        );
        break;
      case 'title':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: v,
          paragraph1: r.paragraph1,
          paragraph2: r.paragraph2,
          imageUrl: r.imageUrl,
          stat1Value: r.stat1Value,
          stat1Label: r.stat1Label,
          stat2Value: r.stat2Value,
          stat2Label: r.stat2Label,
        );
        break;
      case 'paragraph1':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: r.title,
          paragraph1: v,
          paragraph2: r.paragraph2,
          imageUrl: r.imageUrl,
          stat1Value: r.stat1Value,
          stat1Label: r.stat1Label,
          stat2Value: r.stat2Value,
          stat2Label: r.stat2Label,
        );
        break;
      case 'paragraph2':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: r.title,
          paragraph1: r.paragraph1,
          paragraph2: v,
          imageUrl: r.imageUrl,
          stat1Value: r.stat1Value,
          stat1Label: r.stat1Label,
          stat2Value: r.stat2Value,
          stat2Label: r.stat2Label,
        );
        break;
      case 'imageUrl':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: r.title,
          paragraph1: r.paragraph1,
          paragraph2: r.paragraph2,
          imageUrl: v,
          stat1Value: r.stat1Value,
          stat1Label: r.stat1Label,
          stat2Value: r.stat2Value,
          stat2Label: r.stat2Label,
        );
        break;
      case 'stat1Value':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: r.title,
          paragraph1: r.paragraph1,
          paragraph2: r.paragraph2,
          imageUrl: r.imageUrl,
          stat1Value: v,
          stat1Label: r.stat1Label,
          stat2Value: r.stat2Value,
          stat2Label: r.stat2Label,
        );
        break;
      case 'stat1Label':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: r.title,
          paragraph1: r.paragraph1,
          paragraph2: r.paragraph2,
          imageUrl: r.imageUrl,
          stat1Value: r.stat1Value,
          stat1Label: v,
          stat2Value: r.stat2Value,
          stat2Label: r.stat2Label,
        );
        break;
      case 'stat2Value':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: r.title,
          paragraph1: r.paragraph1,
          paragraph2: r.paragraph2,
          imageUrl: r.imageUrl,
          stat1Value: r.stat1Value,
          stat1Label: r.stat1Label,
          stat2Value: v,
          stat2Label: r.stat2Label,
        );
        break;
      case 'stat2Label':
        next = HomeRootsSettings(
          subheading: r.subheading,
          title: r.title,
          paragraph1: r.paragraph1,
          paragraph2: r.paragraph2,
          imageUrl: r.imageUrl,
          stat1Value: r.stat1Value,
          stat1Label: r.stat1Label,
          stat2Value: r.stat2Value,
          stat2Label: v,
        );
        break;
      default:
        return;
    }
    setState(() {
      _edit = HomePageSettings(hero: d.hero, roots: next, seasonal: d.seasonal);
      _dirty = true;
    });
  }

  void _setSeasonal(String k, String v) {
    final d = _ensureDraft();
    final s = d.seasonal ?? const HomeSeasonalSettings(cards: <HomeSeasonalCard>[]);
    HomeSeasonalSettings next;
    switch (k) {
      case 'heading':
        next = HomeSeasonalSettings(heading: v, subheading: s.subheading, cards: _seasonalCards(d));
        break;
      case 'subheading':
        next = HomeSeasonalSettings(heading: s.heading, subheading: v, cards: _seasonalCards(d));
        break;
      default:
        return;
    }
    setState(() {
      _edit = HomePageSettings(hero: d.hero, roots: d.roots, seasonal: next);
      _dirty = true;
    });
  }

  void _setCard(int idx, String k, String v) {
    final d = _ensureDraft();
    final s = d.seasonal ?? const HomeSeasonalSettings(cards: <HomeSeasonalCard>[]);
    final cards = _seasonalCards(d);
    final cur = cards[idx];
    final nextCard = HomeSeasonalCard(title: k == 'title' ? v : cur.title, imageUrl: k == 'imageUrl' ? v : cur.imageUrl);
    cards[idx] = nextCard;
    final nextSeasonal = HomeSeasonalSettings(heading: s.heading, subheading: s.subheading, cards: cards);
    setState(() {
      _edit = HomePageSettings(hero: d.hero, roots: d.roots, seasonal: nextSeasonal);
      _dirty = true;
    });
  }

  Future<void> _uploadTo(String key, void Function(String url) onUrl) async {
    setState(() {
      _uploadingKey = key;
      _err = null;
    });
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (!mounted) return;
      if (picked == null) return;
      final url = await _api.adminUploadHomeImage(picked.path);
      if (!mounted) return;
      onUrl(url);
      setState(() => _dirty = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _uploadingKey = null);
    }
  }

  Future<void> _save() async {
    final token = (AuthState.token.value ?? '').trim();
    if (token.isEmpty) {
      setState(() => _err = 'Vui lòng đăng nhập tài khoản Admin.');
      return;
    }
    final d = _edit;
    if (d == null) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final cards = _seasonalCards(d);
      final next = HomePageSettings(
        hero: d.hero,
        roots: d.roots,
        seasonal: HomeSeasonalSettings(
          heading: d.seasonal?.heading,
          subheading: d.seasonal?.subheading,
          cards: cards,
        ),
      );
      await _api.adminUpdateHomePageSettings(next);
      if (!mounted) return;
      setState(() {
        _data = next;
        _edit = next;
        _dirty = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thiết lập trang chủ.')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e'.replaceFirst('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _edit ?? _data;
    final heroImg = _resolveMediaUrl(d?.hero?.imageUrl ?? '');
    final rootsImg = _resolveMediaUrl(d?.roots?.imageUrl ?? '');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập trang chủ'),
        actions: [
          TextButton(
            onPressed: (_saving || _loading || !_dirty) ? null : _save,
            child: _saving ? const Text('Đang lưu…') : const Text('Lưu thay đổi'),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cấu hình HomePage', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                  'Chỉnh sửa 3 section tĩnh: Hero, Our Roots, Seasonal Collections. App sẽ dùng API admin giống web.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_err != null)
            Text(_err!, style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFFB91C1C), fontWeight: FontWeight.w800))
          else if (d == null)
            Text('Chưa có dữ liệu cấu hình.', style: theme.textTheme.bodyMedium)
          else ...[
            _Section(
              title: 'Hero',
              child: Column(
                children: [
                  _Field(label: 'Eyebrow', value: d.hero?.eyebrow ?? '', onChanged: (v) => _setHero('eyebrow', v)),
                  _ImageRow(
                    label: 'Ảnh (URL)',
                    value: d.hero?.imageUrl ?? '',
                    uploading: _uploadingKey != null,
                    uploadingThis: _uploadingKey == 'hero',
                    onChanged: (v) => _setHero('imageUrl', v),
                    onUpload: () => _uploadTo('hero', (url) => _setHero('imageUrl', url)),
                  ),
                  _Field(label: 'Title', value: d.hero?.title ?? '', onChanged: (v) => _setHero('title', v)),
                  _Field(label: 'Highlight', value: d.hero?.highlight ?? '', onChanged: (v) => _setHero('highlight', v)),
                  _TextArea(label: 'Subtitle', value: d.hero?.subtitle ?? '', onChanged: (v) => _setHero('subtitle', v)),
                  _Field(label: 'CTA 1 text', value: d.hero?.primaryCtaText ?? '', onChanged: (v) => _setHero('primaryCtaText', v)),
                  _Field(label: 'CTA 1 link', value: d.hero?.primaryCtaHref ?? '', onChanged: (v) => _setHero('primaryCtaHref', v)),
                  _Field(label: 'CTA 2 text', value: d.hero?.secondaryCtaText ?? '', onChanged: (v) => _setHero('secondaryCtaText', v)),
                  _Field(
                    label: 'CTA 2 link (để trống = button)',
                    value: d.hero?.secondaryCtaHref ?? '',
                    onChanged: (v) => _setHero('secondaryCtaHref', v),
                  ),
                  _Field(label: 'Feature 1 title', value: d.hero?.feature1Title ?? '', onChanged: (v) => _setHero('feature1Title', v)),
                  _Field(label: 'Feature 1 sub', value: d.hero?.feature1Sub ?? '', onChanged: (v) => _setHero('feature1Sub', v)),
                  _Field(label: 'Feature 2 title', value: d.hero?.feature2Title ?? '', onChanged: (v) => _setHero('feature2Title', v)),
                  _Field(label: 'Feature 2 sub', value: d.hero?.feature2Sub ?? '', onChanged: (v) => _setHero('feature2Sub', v)),
                  if (heroImg.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PreviewImage(url: heroImg),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Section(
              title: 'Our Roots',
              child: Column(
                children: [
                  _Field(label: 'Subheading', value: d.roots?.subheading ?? '', onChanged: (v) => _setRoots('subheading', v)),
                  _ImageRow(
                    label: 'Ảnh (URL)',
                    value: d.roots?.imageUrl ?? '',
                    uploading: _uploadingKey != null,
                    uploadingThis: _uploadingKey == 'roots',
                    onChanged: (v) => _setRoots('imageUrl', v),
                    onUpload: () => _uploadTo('roots', (url) => _setRoots('imageUrl', url)),
                  ),
                  _Field(label: 'Title', value: d.roots?.title ?? '', onChanged: (v) => _setRoots('title', v)),
                  _TextArea(label: 'Paragraph 1', value: d.roots?.paragraph1 ?? '', onChanged: (v) => _setRoots('paragraph1', v)),
                  _TextArea(label: 'Paragraph 2', value: d.roots?.paragraph2 ?? '', onChanged: (v) => _setRoots('paragraph2', v)),
                  _Field(label: 'Stat 1 value', value: d.roots?.stat1Value ?? '', onChanged: (v) => _setRoots('stat1Value', v)),
                  _Field(label: 'Stat 1 label', value: d.roots?.stat1Label ?? '', onChanged: (v) => _setRoots('stat1Label', v)),
                  _Field(label: 'Stat 2 value', value: d.roots?.stat2Value ?? '', onChanged: (v) => _setRoots('stat2Value', v)),
                  _Field(label: 'Stat 2 label', value: d.roots?.stat2Label ?? '', onChanged: (v) => _setRoots('stat2Label', v)),
                  if (rootsImg.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PreviewImage(url: rootsImg),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Section(
              title: 'Seasonal Collections',
              child: Column(
                children: [
                  _Field(label: 'Heading', value: d.seasonal?.heading ?? '', onChanged: (v) => _setSeasonal('heading', v)),
                  _Field(label: 'Subheading', value: d.seasonal?.subheading ?? '', onChanged: (v) => _setSeasonal('subheading', v)),
                  const SizedBox(height: 6),
                  for (final idx in [0, 1, 2]) ...[
                    if (idx != 0) const SizedBox(height: 12),
                    _CardDivider(title: 'Card ${idx + 1}'),
                    _Field(
                      label: 'Card ${idx + 1} title',
                      value: _seasonalCards(d)[idx].title,
                      onChanged: (v) => _setCard(idx, 'title', v),
                    ),
                    _ImageRow(
                      label: 'Card ${idx + 1} image (URL)',
                      value: _seasonalCards(d)[idx].imageUrl,
                      uploading: _uploadingKey != null,
                      uploadingThis: _uploadingKey == 'seasonal-$idx',
                      onChanged: (v) => _setCard(idx, 'imageUrl', v),
                      onUpload: () => _uploadTo('seasonal-$idx', (url) => _setCard(idx, 'imageUrl', url)),
                    ),
                    if (_resolveMediaUrl(_seasonalCards(d)[idx].imageUrl).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _PreviewImage(url: _resolveMediaUrl(_seasonalCards(d)[idx].imageUrl)),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  final String title;
  const _CardDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _Field({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('$label|$value'),
            initialValue: value,
            onChanged: onChanged,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}

class _TextArea extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const _TextArea({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('$label|$value'),
            initialValue: value,
            onChanged: onChanged,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onUpload;
  final bool uploading;
  final bool uploadingThis;
  const _ImageRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onUpload,
    required this.uploading,
    required this.uploadingThis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('$label|$value'),
                  initialValue: value,
                  onChanged: onChanged,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: uploading ? null : onUpload,
                child: Text(uploadingThis ? 'Đang upload…' : 'Upload'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  final String url;
  const _PreviewImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant)),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Không tải được ảnh', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
