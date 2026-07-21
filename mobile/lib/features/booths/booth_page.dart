import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../layout/app_layout.dart';
import '../../widgets/common.dart';
import '../../widgets/mobile_components.dart';

class BoothPage extends StatefulWidget {
  const BoothPage({super.key});

  @override
  State<BoothPage> createState() => _BoothPageState();
}

class _BoothPageState extends State<BoothPage> {
  @override
  Widget build(BuildContext context) => FutureBlock<List<dynamic>>(
        load: () => api.list('/api/booths'),
        builder: (items) => AppPage(children: [
          PremiumFeatureHero(
            title: 'बूथ प्रबंधन',
            subtitle: 'बूथ, वार्ड और पते की जानकारी एक जगह आसानी से संभालें।',
            icon: Icons.how_to_vote_rounded,
            badges: const ['वार्ड से जुड़ा', 'व्यवस्थित', 'सुरक्षित'],
            action: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('नया बूथ'),
            ),
          ),
          PremiumSectionTitle(
            title: 'सभी बूथ (${items.length})',
            subtitle: 'जानकारी बदलने के लिए बूथ कार्ड पर टैप करें',
            icon: Icons.location_city_rounded,
          ),
          if (items.isEmpty)
            PremiumEmptyState(
              icon: Icons.how_to_vote_outlined,
              title: 'अभी कोई बूथ नहीं है',
              subtitle: 'पहला बूथ जोड़कर प्रबंधन शुरू करें',
              action: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('बूथ जोड़ें'),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border),
              ),
              child: Column(
                children: items.map((raw) {
                  final booth = Map<String, dynamic>.from(raw as Map);
                  final ward =
                      booth['ward'] is Map ? booth['ward'] as Map : const {};
                  return InkWell(
                    onTap: () => _openForm(booth),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Color(0xffedf0f5))),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: softBlue),
                          child: const Icon(Icons.how_to_vote_rounded,
                              color: blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'बूथ ${booth['number'] ?? '-'} · ${booth['name'] ?? '-'}',
                                    style: const TextStyle(
                                        color: navy,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 3),
                                Text(
                                    [
                                      if ('${ward['number'] ?? ''}'.isNotEmpty)
                                        'वार्ड ${ward['number']}',
                                      '${booth['area'] ?? ''}',
                                      '${booth['address'] ?? ''}',
                                    ]
                                        .where(
                                            (value) => value.trim().isNotEmpty)
                                        .join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: muted, fontSize: 11)),
                              ]),
                        ),
                        const Icon(Icons.edit_rounded, color: blue, size: 20),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
        ]),
      );

  Future<void> _openForm([Map<String, dynamic>? booth]) async {
    try {
      final wards = (await api.list('/api/wards'))
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BoothFormSheet(booth: booth, wards: wards),
      );
      if (saved == true && mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(booth == null
              ? 'नया बूथ सफलतापूर्वक जोड़ दिया गया।'
              : 'बूथ की जानकारी अपडेट हो गई।'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }
}

class _BoothFormSheet extends StatefulWidget {
  const _BoothFormSheet({required this.booth, required this.wards});

  final Map<String, dynamic>? booth;
  final List<Map<String, dynamic>> wards;

  @override
  State<_BoothFormSheet> createState() => _BoothFormSheetState();
}

class _BoothFormSheetState extends State<_BoothFormSheet> {
  final formKey = GlobalKey<FormState>();
  late final number =
      TextEditingController(text: '${widget.booth?['number'] ?? ''}');
  late final name =
      TextEditingController(text: '${widget.booth?['name'] ?? ''}');
  late final area =
      TextEditingController(text: '${widget.booth?['area'] ?? ''}');
  late final address =
      TextEditingController(text: '${widget.booth?['address'] ?? ''}');
  late String? wardId = _idOf(widget.booth?['ward']);
  bool saving = false;
  bool active = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    active = widget.booth?['active'] != false;
    if (!widget.wards.any((ward) => '${ward['_id']}' == wardId)) {
      wardId = null;
    }
  }

  @override
  void dispose() {
    number.dispose();
    name.dispose();
    area.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (wardId == null || wardId!.isEmpty) {
      setState(() => error = 'कृपया बूथ का वार्ड चुनें।');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final body = {
        'number': number.text.trim(),
        'name': name.text.trim(),
        'ward': wardId,
        'area': area.text.trim(),
        'address': address.text.trim(),
        'active': active,
      };
      if (widget.booth == null) {
        await api.post('/api/booths', body);
      } else {
        await api.put('/api/booths/${widget.booth!['_id']}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.booth == null;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xffd7deeb),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: softBlue,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.how_to_vote_rounded, color: blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isNew ? 'नया बूथ बनाएं' : 'बूथ संपादित करें',
                            style: const TextStyle(
                                color: navy,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        const Text(
                            'पहले वार्ड चुनें, फिर बूथ की पहचान और स्थान भरें।',
                            style: TextStyle(color: muted, fontSize: 12)),
                      ]),
                ),
                IconButton(
                  tooltip: 'बंद करें',
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 18),
              _FormSection(
                number: '1',
                title: 'वार्ड चुनें',
                subtitle: 'बूथ हमेशा किसी मौजूदा वार्ड से जुड़ा होगा।',
                child: widget.wards.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xfffff5e8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffffd8a8)),
                        ),
                        child: const Text(
                            'पहले वार्ड प्रबंधन में कम-से-कम एक वार्ड जोड़ें।',
                            style: TextStyle(
                                color: Color(0xff9a5500),
                                fontWeight: FontWeight.w800)),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: wardId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'वार्ड *',
                          prefixIcon: Icon(Icons.map_rounded),
                          helperText: 'सूची से सही वार्ड चुनें',
                        ),
                        items: widget.wards
                            .map((ward) => DropdownMenuItem<String>(
                                  value: '${ward['_id']}',
                                  child: Text(
                                    'वार्ड ${ward['number'] ?? '-'} · ${ward['name'] ?? 'बिना नाम'}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        validator: (value) => value == null || value.isEmpty
                            ? 'वार्ड चुनना जरूरी है'
                            : null,
                        onChanged: saving
                            ? null
                            : (value) => setState(() => wardId = value),
                      ),
              ),
              const SizedBox(height: 12),
              _FormSection(
                number: '2',
                title: 'बूथ की पहचान',
                subtitle: 'बूथ संख्या और सरल पहचान वाला नाम लिखें।',
                child: LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final fields = [
                    Expanded(
                      child: TextFormField(
                        controller: number,
                        enabled: !saving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'बूथ संख्या *',
                          hintText: 'जैसे 24',
                          prefixIcon: Icon(Icons.numbers_rounded),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'बूथ संख्या जरूरी है'
                            : null,
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: name,
                        enabled: !saving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'बूथ का नाम *',
                          hintText: 'जैसे प्राथमिक विद्यालय',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'बूथ का नाम जरूरी है'
                            : null,
                      ),
                    ),
                  ];
                  if (compact) {
                    return Column(children: [
                      SizedBox(width: double.infinity, child: fields[0].child),
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: fields[1].child),
                    ]);
                  }
                  return Row(children: [
                    fields[0],
                    const SizedBox(width: 12),
                    fields[1],
                  ]);
                }),
              ),
              const SizedBox(height: 12),
              _FormSection(
                number: '3',
                title: 'स्थान की जानकारी',
                subtitle: 'यह जानकारी बाद में बूथ खोजने में मदद करेगी।',
                child: Column(children: [
                  TextFormField(
                    controller: area,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'क्षेत्र / गाँव',
                      hintText: 'जैसे भीटा',
                      prefixIcon: Icon(Icons.location_city_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: address,
                    enabled: !saving,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'पूरा पता',
                      hintText: 'भवन, सड़क या पहचान लिखें',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: saving
                        ? null
                        : (value) => setState(() => active = value),
                    title: const Text('बूथ सक्रिय रखें',
                        style: TextStyle(
                            color: navy, fontWeight: FontWeight.w800)),
                    subtitle: const Text('नए मतदाता इस बूथ से जोड़े जा सकेंगे'),
                  ),
                ]),
              ),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffffeeee),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(error,
                      style: const TextStyle(
                          color: Color(0xffb42318),
                          fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: saving || widget.wards.isEmpty ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_rounded),
                  label: Text(saving
                      ? 'सहेजा जा रहा है...'
                      : isNew
                          ? 'बूथ बनाएं'
                          : 'बदलाव सहेजें'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfff8faff),
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: blue,
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: navy, fontWeight: FontWeight.w900)),
                    Text(subtitle,
                        style: const TextStyle(color: muted, fontSize: 11)),
                  ]),
            ),
          ]),
          const SizedBox(height: 13),
          child,
        ]),
      );
}

String? _idOf(dynamic value) {
  if (value is Map) return '${value['_id'] ?? ''}';
  final text = '${value ?? ''}';
  return text.isEmpty ? null : text;
}
