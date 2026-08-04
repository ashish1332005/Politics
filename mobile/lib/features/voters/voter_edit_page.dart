import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/contact_actions.dart';
import '../../core/offline_voter_cache.dart';
import '../../core/picked_file_source.dart';
import '../../core/print_helper.dart';
import '../../core/theme.dart';

class VoterEditPage extends StatefulWidget {
  const VoterEditPage({super.key, required this.voter, required this.onSaved});
  final Map<String, dynamic> voter;
  final VoidCallback onSaved;

  @override
  State<VoterEditPage> createState() => _VoterEditPageState();
}

class _VoterEditPageState extends State<VoterEditPage> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  bool saving = false;
  PlatformFile? selectedPhoto;
  String gender = '';
  String relationType = '';
  String supportLevel = 'undecided';
  String verificationStatus = 'pending';

  static const fieldKeys = [
    'name',
    'surname',
    'guardianName',
    'age',
    'dob',
    'mobile',
    'altMobile',
    'voterId',
    'voterSerial',
    'houseNumber',
    'address',
    'location',
    'assemblyNumber',
    'assemblyName',
    'partNumber',
    'sectionNumber',
    'sectionName',
    'tehsil',
    'gramPanchayat',
    'village',
    'municipality',
    'caste',
    'subCaste',
    'organizationPost',
    'organizationLevel',
    'occupation',
    'education',
    'anniversary',
    'notes',
  ];

  @override
  void initState() {
    super.initState();
    for (final key in fieldKeys) {
      fields[key] = TextEditingController(text: _value(widget.voter[key], key));
    }
    gender = '${widget.voter['gender'] ?? ''}';
    relationType = '${widget.voter['relationType'] ?? ''}';
    supportLevel = '${widget.voter['supportLevel'] ?? 'undecided'}';
    verificationStatus = '${widget.voter['verificationStatus'] ?? 'pending'}';
  }

  String _value(dynamic value, [String key = '']) {
    if (value == null) return '';
    final text = '$value';
    final parsed = DateTime.tryParse(text);
    if ((key == 'dob' || key == 'anniversary') && parsed != null) {
      return DateFormat('MM-dd').format(parsed.toLocal());
    }
    return text.contains('T') && text.length >= 10
        ? text.substring(0, 10)
        : text;
  }

  DateTime _monthDayInitial(String key) {
    final text = fields[key]?.text.trim() ?? '';
    final parts = text.split('-');
    if (parts.length == 2) {
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      if (month != null && day != null) return DateTime(2000, month, day);
    }
    final parsed = DateTime.tryParse(text);
    return parsed == null ? DateTime(2000, DateTime.now().month, DateTime.now().day) : DateTime(2000, parsed.month, parsed.day);
  }

  Future<DateTime?> _pickMonthDay(String key, String label) async {
    var selected = _monthDayInitial(key);
    return showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        final days = DateUtils.getDaysInMonth(2000, selected.month);
        return AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                initialValue: selected.month,
                decoration: const InputDecoration(labelText: 'महीना'),
                items: List.generate(12, (i) => i + 1)
                    .map((month) => DropdownMenuItem(
                          value: month,
                          child: Text(DateFormat('MMMM').format(DateTime(2000, month, 1))),
                        ))
                    .toList(),
                onChanged: (month) => setDialogState(() {
                  if (month == null) return;
                  final maxDay = DateUtils.getDaysInMonth(2000, month);
                  selected = DateTime(2000, month, selected.day.clamp(1, maxDay));
                }),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: GridView.count(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: List.generate(days, (i) {
                    final day = i + 1;
                    final picked = day == selected.day;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setDialogState(() => selected = DateTime(2000, selected.month, day)),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: picked ? blue : const Color(0xfff3f6fb),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$day', style: TextStyle(color: picked ? Colors.white : navy, fontWeight: FontWeight.w800)),
                      ),
                    );
                  }),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Select')),
          ],
        );
      }),
    );
  }

  Future<void> save({bool addAnother = false}) async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final body = <String, dynamic>{
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
        'gender': gender,
        'relationType': relationType,
        'supportLevel': supportLevel,
        'verificationStatus': verificationStatus,
      };
      if (body['age'] == '') body['age'] = null;
      for (final dateKey in ['dob', 'anniversary']) {
        final original = widget.voter[dateKey];
        final originalText = original == null ? '' : '$original'.trim();
        if ('${body[dateKey] ?? ''}'.trim().isEmpty && originalText.isEmpty) {
          body.remove(dateKey);
        }
      }
      late final dynamic updated;
      if (selectedPhoto != null) {
        updated = await api.uploadFile(
          '/api/members/${widget.voter['_id']}',
          method: 'PUT',
          filename: selectedPhoto!.name,
          fileField: 'photo',
          filePath: pickedFilePath(selectedPhoto!),
          bytes: pickedFileBytes(selectedPhoto!),
          fields: body.map(
              (key, value) => MapEntry(key, value == null ? '' : '$value')),
        );
      } else {
        updated = await api.put('/api/members/${widget.voter['_id']}', body);
      }
      if (updated is Map<String, dynamic>) {
        await OfflineVoterCache.merge([updated]);
      }
      api.notifyDataChanged();
      widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('मतदाता जानकारी सहेज दी गई')));
      if (addAnother) {
        Navigator.pop(context);
      } else {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('मतदाता हटाएं?'),
        content: const Text('यह रिकॉर्ड स्थायी रूप से हट जाएगा।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('रद्द करें')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('हटाएं')),
        ],
      ),
    );
    if (yes != true) return;
    final voterId = '${widget.voter['_id']}';
    await api.delete('/api/members/$voterId');
    await OfflineVoterCache.removeByIds([voterId]);
    api.notifyDataChanged();
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xfff7f8fb),
        appBar: AppBar(
          toolbarHeight: 66,
          backgroundColor: Colors.white,
          foregroundColor: navy,
          surfaceTintColor: Colors.white,
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('मतदाता संपादित करें',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w900)),
                Text('मतदाता की जानकारी अपडेट करें',
                    style: TextStyle(color: muted, fontSize: 11)),
              ]),
          actions: [
            IconButton.filledTonal(
              tooltip: 'प्रोफाइल प्रिंट करें',
              onPressed: () => printApiPdf(context,
                  path: '/api/export/members/${widget.voter['_id']}.pdf',
                  jobName: 'मतदाता प्रोफाइल'),
              icon: const Icon(Icons.print_rounded, color: blue),
            ),
            const SizedBox(width: 12),
          ],
        ),
        bottomNavigationBar: _stickySaveBar(),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _profile(),
              _section('व्यक्तिगत जानकारी', Icons.person_outline, [
                _field('name', 'नाम *',
                    icon: Icons.person_rounded, required: true),
                _field('surname', 'उपनाम', icon: Icons.badge_rounded),
                _field('guardianName', 'पिता / पति का नाम',
                    icon: Icons.family_restroom_rounded),
                _dropdown(
                    'संबंध',
                    relationType,
                    const {
                      '': 'चुनें',
                      'father': 'पिता',
                      'husband': 'पति',
                      'mother': 'माता',
                      'other': 'अन्य'
                    },
                    (v) => relationType = v),
                _field('age', 'उम्र', icon: Icons.cake_rounded, number: true),
                _dateField('dob', 'जन्म तिथि'),
                _genderCards(),
                _dateField('anniversary', 'विवाह वर्षगांठ'),
                _field('mobile', 'मोबाइल नंबर',
                    icon: Icons.call_rounded, number: true),
                _field('altMobile', 'वैकल्पिक मोबाइल नंबर',
                    icon: Icons.phone_iphone_rounded, number: true),
              ]),
              _section('पता एवं चुनाव जानकारी', Icons.home_outlined, [
                _field('houseNumber', 'घर संख्या'),
                _field('address', 'पूरा पता', lines: 3),
                _field('location', 'स्थान / क्षेत्र'),
                _field('voterId', 'मतदाता आईडी (EPIC)'),
                _field('voterSerial', 'मतदाता क्रमांक'),
                _field('assemblyNumber', 'विधानसभा संख्या'),
                _field('assemblyName', 'विधानसभा क्षेत्र'),
                _field('partNumber', 'भाग / बूथ संख्या'),
                _field('sectionNumber', 'अनुभाग संख्या'),
                _field('sectionName', 'अनुभाग नाम'),
                _field('tehsil', 'तहसील'),
                _field('gramPanchayat', 'ग्राम पंचायत'),
                _field('village', 'गाँव'),
                _field('municipality', 'नगर पालिका / वार्ड'),
              ]),
              _section('राजनीतिक जानकारी', Icons.groups_outlined, [
                _dropdown(
                    'समर्थन स्तर',
                    supportLevel,
                    const {
                      'supporter': 'समर्थक',
                      'neutral': 'तटस्थ',
                      'opposite': 'विरोधी',
                      'undecided': 'अनिर्णीत'
                    },
                    (v) => supportLevel = v),
                _dropdown(
                    'सत्यापन स्थिति',
                    verificationStatus,
                    const {
                      'pending': 'लंबित',
                      'verified': 'सत्यापित',
                      'needs_review': 'पुनः जांच',
                      'duplicate': 'डुप्लीकेट'
                    },
                    (v) => verificationStatus = v),
                _field('organizationPost', 'राजनीतिक / सामाजिक पद'),
                _field('organizationLevel', 'पद स्तर (गाँव/मंडल/ब्लॉक/जिला)'),
                _field('caste', 'जाति'),
                _field('subCaste', 'उपजाति'),
                _field('notes', 'टिप्पणी / विशेष जानकारी',
                    lines: 4, full: true),
              ]),
              _section('व्यवसाय एवं अन्य जानकारी', Icons.work_outline, [
                _field('occupation', 'व्यवसाय'),
                _field('education', 'शिक्षा'),
              ]),
              _dangerActions(),
            ],
          ),
        ),
      );

  Widget _profile() {
    final mobile =
        fields['mobile']?.text.trim() ?? '${widget.voter['mobile'] ?? ''}';
    final name = fields['name']?.text.trim().isNotEmpty == true
        ? fields['name']!.text.trim()
        : '${widget.voter['name'] ?? '-'}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0f071b4b),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: _pickPhoto,
            borderRadius: BorderRadius.circular(24),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: blue.withValues(alpha: .25), width: 2),
                ),
                child: ClipOval(
                  child:
                      SizedBox(width: 100, height: 100, child: _photoPreview()),
                ),
              ),
              Positioned(
                right: -4,
                bottom: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: blue,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x330d6efd), blurRadius: 10),
                    ],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 15),
                    SizedBox(width: 4),
                    Text('फोटो',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: navy)),
                const SizedBox(height: 8),
                _ProfileMiniRow(
                    Icons.badge_outlined,
                    'मतदाता आईडी (EPIC)',
                    fields['voterId']!.text.isEmpty
                        ? '-'
                        : fields['voterId']!.text),
                const SizedBox(height: 5),
                _ProfileMiniRow(
                    Icons.tag_rounded,
                    'मतदाता क्रमांक',
                    fields['voterSerial']!.text.isEmpty
                        ? '-'
                        : fields['voterSerial']!.text),
                const SizedBox(height: 8),
                Text(
                    'अंतिम अपडेट: ${_formattedDate(widget.voter['updatedAt'])}',
                    style: const TextStyle(color: muted, fontSize: 12)),
              ])),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 9, runSpacing: 9, children: [
          _HeroAction(
            icon: Icons.call_rounded,
            label: 'कॉल',
            color: green,
            onTap: () => callNumber(context, mobile),
          ),
          _HeroAction(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xff25d366),
            onTap: () =>
                openWhatsApp(context, mobile, message: 'नमस्कार $name जी,'),
          ),
          _HeroAction(
            icon: Icons.sms_rounded,
            label: 'SMS',
            color: blue,
            onTap: _sendSms,
          ),
          _HeroAction(
            icon: Icons.bookmark_border_rounded,
            label: 'सेव करें',
            color: navy,
            onTap: saving ? null : save,
          ),
        ]),
      ]),
    );
  }

  Future<void> _sendSms() async {
    final mobile = (fields['mobile']?.text ?? '${widget.voter['mobile'] ?? ''}')
        .replaceAll(RegExp(r'\D'), '');
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('SMS के लिए मोबाइल नंबर उपलब्ध नहीं है।')));
      return;
    }
    final uri = Uri.parse('sms:$mobile');
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('SMS app नहीं खुल सकी।')));
    }
  }

  Widget _genderCards() => _FullWidth(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('लिंग',
              style: TextStyle(color: muted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _ChoiceCard(
              selected: gender == 'male',
              icon: Icons.male_rounded,
              label: 'पुरुष',
              onTap: () => setState(() => gender = 'male'),
            ),
            _ChoiceCard(
              selected: gender == 'female',
              icon: Icons.female_rounded,
              label: 'महिला',
              onTap: () => setState(() => gender = 'female'),
            ),
            _ChoiceCard(
              selected: gender == 'other',
              icon: Icons.person_outline_rounded,
              label: 'अन्य',
              onTap: () => setState(() => gender = 'other'),
            ),
          ]),
        ]),
      );

  Widget _stickySaveBar() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: border)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x14071b4b),
                  blurRadius: 18,
                  offset: Offset(0, -8)),
            ],
          ),
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth > 680;
            final buttons = Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: wide ? 150 : 0,
                child: wide
                    ? OutlinedButton.icon(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('रद्द करें'),
                      )
                    : const SizedBox.shrink(),
              ),
              if (wide) const SizedBox(width: 12),
              SizedBox(
                width: wide ? 260 : box.maxWidth,
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(saving ? 'सहेज रहे हैं...' : 'सुरक्षित करें'),
                ),
              ),
            ]);
            if (!wide) return buttons;
            return Row(children: [
              const Icon(Icons.verified_user_rounded, color: green, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('बदलाव save करने के बाद voter list refresh होगी',
                    style:
                        TextStyle(color: muted, fontWeight: FontWeight.w700)),
              ),
              buttons,
            ]);
          }),
        ),
      );

  Widget _photoPreview() {
    if (selectedPhoto?.bytes != null) {
      return Image.memory(selectedPhoto!.bytes!, fit: BoxFit.contain);
    }
    final photo = '${widget.voter['photo'] ?? ''}';
    if (photo.isNotEmpty) {
      return Image.network(
        photo.startsWith('http') ? photo : '${api.baseUrl}$photo',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 52),
      );
    }
    return const ColoredBox(
        color: Color(0xffeef3ff), child: Icon(Icons.person, size: 52));
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    if (result == null || !mounted) return;
    setState(() => selectedPhoto = result.files.single);
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: blue),
              const SizedBox(width: 9),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900, color: navy))
            ]),
            const Divider(height: 24),
            LayoutBuilder(builder: (context, box) {
              final width =
                  box.maxWidth < 700 ? box.maxWidth : (box.maxWidth - 24) / 3;
              return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: children
                      .map((child) => SizedBox(
                          width: child is _FullWidth ? box.maxWidth : width,
                          child: child is _FullWidth ? child.child : child))
                      .toList());
            }),
          ]),
        ),
      );

  Widget _field(String key, String label,
      {bool required = false,
      bool number = false,
      int lines = 1,
      bool full = false,
      bool readOnly = false,
      IconData? icon}) {
    final field = TextFormField(
      controller: fields[key],
      readOnly: readOnly,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
      ),
      validator: required
          ? (value) =>
              value == null || value.trim().isEmpty ? '$label आवश्यक है' : null
          : null,
    );
    return full ? _FullWidth(field) : field;
  }

  Widget _dateField(String key, String label) => TextFormField(
        controller: fields[key],
        readOnly: true,
        decoration: InputDecoration(
            labelText: label,
            helperText: key == 'dob' ? 'सिर्फ तारीख और महीना चुनें — year नहीं' : 'तारीख और महीना चुनें',
            prefixIcon: const Icon(Icons.calendar_today_rounded),
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (fields[key]!.text.isNotEmpty)
                IconButton(
                  tooltip: 'तारीख हटाएँ',
                  onPressed: () => setState(() => fields[key]!.clear()),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.calendar_month_outlined),
              ),
            ])),
        onTap: () async {
          final date = await _pickMonthDay(key, label);
          if (date != null) {
            setState(() => fields[key]!.text = DateFormat('MM-dd').format(date));
          }
        },
      );

  Widget _dropdown(String label, String value, Map<String, String> items,
          ValueChanged<String> changed) =>
      DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : items.keys.first,
        decoration: InputDecoration(labelText: label),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (v) => setState(() {
          if (v != null) changed(v);
        }),
      );

  Widget _dangerActions() => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                  onPressed: saving ? null : remove,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label:
                      const Text('हटाएं', style: TextStyle(color: Colors.red))),
            ]),
      );

  String _formattedDate(dynamic raw) {
    final date = DateTime.tryParse('${raw ?? ''}');
    return date == null
        ? '-'
        : DateFormat('dd MMM yyyy, hh:mm a').format(date.toLocal());
  }
}

class _FullWidth extends StatelessWidget {
  const _FullWidth(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 116,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .18)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: navy, fontSize: 12, fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 124,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? softBlue : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? blue : border, width: 1.2),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: selected ? blue : muted, size: 21),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: selected ? blue : navy,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      );
}

class _ProfileMiniRow extends StatelessWidget {
  const _ProfileMiniRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: softBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: blue, size: 15),
        ),
        const SizedBox(width: 9),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: muted, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: navy, fontSize: 14, fontWeight: FontWeight.w900)),
          ]),
        ),
      ]);
}
