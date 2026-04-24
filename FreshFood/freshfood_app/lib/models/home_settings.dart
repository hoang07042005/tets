class HomeHeroSettings {
  final String? eyebrow;
  final String? title;
  final String? highlight;
  final String? subtitle;
  final String? primaryCtaText;
  final String? primaryCtaHref;
  final String? secondaryCtaText;
  final String? secondaryCtaHref;
  final String? imageUrl;
  final String? feature1Title;
  final String? feature1Sub;
  final String? feature2Title;
  final String? feature2Sub;

  const HomeHeroSettings({
    this.eyebrow,
    this.title,
    this.highlight,
    this.subtitle,
    this.primaryCtaText,
    this.primaryCtaHref,
    this.secondaryCtaText,
    this.secondaryCtaHref,
    this.imageUrl,
    this.feature1Title,
    this.feature1Sub,
    this.feature2Title,
    this.feature2Sub,
  });

  factory HomeHeroSettings.fromJson(Map<String, dynamic> json) {
    String? s(String k) => json[k] is String ? (json[k] as String) : (json[k]?.toString());
    return HomeHeroSettings(
      eyebrow: s('eyebrow'),
      title: s('title'),
      highlight: s('highlight'),
      subtitle: s('subtitle'),
      primaryCtaText: s('primaryCtaText'),
      primaryCtaHref: s('primaryCtaHref'),
      secondaryCtaText: s('secondaryCtaText'),
      secondaryCtaHref: s('secondaryCtaHref'),
      imageUrl: s('imageUrl'),
      feature1Title: s('feature1Title'),
      feature1Sub: s('feature1Sub'),
      feature2Title: s('feature2Title'),
      feature2Sub: s('feature2Sub'),
    );
  }

  Map<String, dynamic> toJson() => {
        'eyebrow': eyebrow,
        'title': title,
        'highlight': highlight,
        'subtitle': subtitle,
        'primaryCtaText': primaryCtaText,
        'primaryCtaHref': primaryCtaHref,
        'secondaryCtaText': secondaryCtaText,
        'secondaryCtaHref': secondaryCtaHref,
        'imageUrl': imageUrl,
        'feature1Title': feature1Title,
        'feature1Sub': feature1Sub,
        'feature2Title': feature2Title,
        'feature2Sub': feature2Sub,
      };
}

class HomeRootsSettings {
  final String? subheading;
  final String? title;
  final String? paragraph1;
  final String? paragraph2;
  final String? imageUrl;
  final String? stat1Value;
  final String? stat1Label;
  final String? stat2Value;
  final String? stat2Label;

  const HomeRootsSettings({
    this.subheading,
    this.title,
    this.paragraph1,
    this.paragraph2,
    this.imageUrl,
    this.stat1Value,
    this.stat1Label,
    this.stat2Value,
    this.stat2Label,
  });

  factory HomeRootsSettings.fromJson(Map<String, dynamic> json) {
    String? s(String k) => json[k] is String ? (json[k] as String) : (json[k]?.toString());
    return HomeRootsSettings(
      subheading: s('subheading'),
      title: s('title'),
      paragraph1: s('paragraph1'),
      paragraph2: s('paragraph2'),
      imageUrl: s('imageUrl'),
      stat1Value: s('stat1Value'),
      stat1Label: s('stat1Label'),
      stat2Value: s('stat2Value'),
      stat2Label: s('stat2Label'),
    );
  }

  Map<String, dynamic> toJson() => {
        'subheading': subheading,
        'title': title,
        'paragraph1': paragraph1,
        'paragraph2': paragraph2,
        'imageUrl': imageUrl,
        'stat1Value': stat1Value,
        'stat1Label': stat1Label,
        'stat2Value': stat2Value,
        'stat2Label': stat2Label,
      };
}

class HomeSeasonalCard {
  final String title;
  final String imageUrl;
  const HomeSeasonalCard({required this.title, required this.imageUrl});

  factory HomeSeasonalCard.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString();
    final imageUrl = (json['imageUrl'] ?? '').toString();
    return HomeSeasonalCard(title: title, imageUrl: imageUrl);
  }

  Map<String, dynamic> toJson() => {'title': title, 'imageUrl': imageUrl};
}

class HomeSeasonalSettings {
  final String? heading;
  final String? subheading;
  final List<HomeSeasonalCard> cards;

  const HomeSeasonalSettings({this.heading, this.subheading, required this.cards});

  factory HomeSeasonalSettings.fromJson(Map<String, dynamic> json) {
    String? s(String k) => json[k] is String ? (json[k] as String) : (json[k]?.toString());
    final raw = json['cards'];
    final cards = <HomeSeasonalCard>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) cards.add(HomeSeasonalCard.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return HomeSeasonalSettings(heading: s('heading'), subheading: s('subheading'), cards: cards);
  }

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'subheading': subheading,
        'cards': cards.map((e) => e.toJson()).toList(growable: false),
      };
}

class HomePageSettings {
  final HomeHeroSettings? hero;
  final HomeRootsSettings? roots;
  final HomeSeasonalSettings? seasonal;

  const HomePageSettings({this.hero, this.roots, this.seasonal});

  factory HomePageSettings.fromJson(Map<String, dynamic> json) {
    final heroRaw = json['hero'];
    final rootsRaw = json['roots'];
    final seasonalRaw = json['seasonal'];
    return HomePageSettings(
      hero: heroRaw is Map ? HomeHeroSettings.fromJson(Map<String, dynamic>.from(heroRaw)) : null,
      roots: rootsRaw is Map ? HomeRootsSettings.fromJson(Map<String, dynamic>.from(rootsRaw)) : null,
      seasonal: seasonalRaw is Map ? HomeSeasonalSettings.fromJson(Map<String, dynamic>.from(seasonalRaw)) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'hero': hero?.toJson(),
        'roots': roots?.toJson(),
        'seasonal': seasonal?.toJson(),
      };
}

