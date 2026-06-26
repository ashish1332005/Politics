import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/picked_file_source.dart';
import '../../core/print_helper.dart';
import '../../core/theme.dart';
import 'voter_contact_actions.dart';

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
      fields[key] = TextEditingController(text: _value(widget.voter[key]));
    }
    gender = '${widget.voter['gender'] ?? ''}';
    relationType = '${widget.voter['relationType'] ?? ''}';
    supportLevel = '${widget.voter['supportLevel'] ?? 'undecided'}';
    verificationStatus = '${widget.voter['verificationStatus'] ?? 'pending'}';
  }

  String _value(dynamic value) {
    if (value == null) return '';
    final text = '$value';
    return text.contains('T') && text.length >= 10
        ? text.substring(0, 10)
        : text;
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
      if (selectedPhoto != null) {
        await api.uploadFile(
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
        await api.put('/api/members/${widget.voter['_id']}', body);
      }
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
    await api.delete('/api/members/${widget.voter['_id']}');
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 78,
          backgroundColor: royalBlue,
          foregroundColor: Colors.white,
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('मतदाता संपादित करें',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                Text('मतदाता की जानकारी अपडेट करें',
                    style: TextStyle(fontSize: 12)),
              ]),
          actions: [
            TextButton.icon(
              onPressed: () => printApiPdf(context,
                  path: '/api/export/members/${widget.voter['_id']}.pdf',
                  jobName: 'मतदाता प्रोफाइल'),
              icon: const Icon(Icons.print, color: Colors.white),
              label: const Text('प्रिंट करें',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _profile(),
              _section('व्यक्तिगत जानकारी', Icons.person_outline, [
                _field('name', 'नाम *', required: true),
                _field('surname', 'उपनाम'),
                _field('guardianName', 'पिता / पति का नाम'),
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
                _field('age', 'उम्र', number: true),
                _dateField('dob', 'जन्म तिथि'),
                _dropdown(
                    'लिंग',
                    gender,
                    const {
                      '': 'चुनें',
                      'male': 'पुरुष',
                      'female': 'महिला',
                      'other': 'अन्य'
                    },
                    (v) => gender = v),
                _dateField('anniversary', 'विवाह वर्षगांठ'),
                _field('mobile', 'मोबाइल नंबर', number: true),
                _field('altMobile', 'वैकल्पिक मोबाइल नंबर', number: true),
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
              _actions(),
            ],
          ),
        ),
      );

  Widget _profile() => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(12),
              child: Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      SizedBox(width: 110, height: 125, child: _photoPreview()),
                ),
                const Positioned(
                    right: 4,
                    bottom: 4,
                    child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.camera_alt_outlined,
                            color: blue, size: 20))),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${widget.voter['name'] ?? '-'}',
                      style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: navy)),
                  const SizedBox(height: 8),
                  Text('मतदाता आईडी (EPIC): ${widget.voter['voterId'] ?? '-'}',
                      style: const TextStyle(color: muted)),
                  Text('मतदाता क्रमांक: ${widget.voter['voterSerial'] ?? '-'}',
                      style: const TextStyle(color: muted)),
                  const SizedBox(height: 10),
                  VoterContactActions(voter: widget.voter),
                  const Divider(),
                  Text(
                      'अंतिम अपडेट: ${_formattedDate(widget.voter['updatedAt'])}',
                      style: const TextStyle(color: muted, fontSize: 12)),
                ])),
          ]),
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
        margin: const EdgeInsets.only(bottom: 16),
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
      bool readOnly = false}) {
    final field = TextFormField(
      controller: fields[key],
      readOnly: readOnly,
      maxLines: lines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
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
            suffixIcon: const Icon(Icons.calendar_month_outlined)),
        onTap: () async {
          final date = await showDatePicker(
              context: context,
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
              initialDate:
                  DateTime.tryParse(fields[key]!.text) ?? DateTime.now());
          if (date != null) {
            fields[key]!.text = DateFormat('yyyy-MM-dd').format(date);
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

  Widget _actions() => Padding(
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
              OutlinedButton.icon(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('रद्द करें')),
              FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saving ? 'सहेज रहे हैं...' : 'सहेजें')),
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
