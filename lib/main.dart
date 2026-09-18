import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مترجم + لغت‌نامه',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _translatedText = '';
  bool _isActive = false; // دکمه فعال‌سازی
  bool _isLoading = false;
  List<String> _dictionary = [];

  @override
  void initState() {
    super.initState();
    _loadDictionary();
  }

  // بارگذاری لغت‌نامه از حافظه
  Future<void> _loadDictionary() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('dictionary') ?? [];
    setState(() {
      _dictionary = list;
    });
  }

  // ذخیره لغت‌نامه
  Future<void> _saveDictionary() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dictionary', _dictionary);
  }

  // ترجمه متن با API رایگان گوگل
  Future<void> _translateText() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final text = Uri.encodeComponent(_controller.text.trim());
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=fa&dt=t&q=$text',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = '';
        for (var item in data[0]) {
          if (item[0] != null) {
            result += item[0];
          }
        }
        setState(() {
          _translatedText = result;
        });
      } else {
        setState(() {
          _translatedText = 'خطا در ترجمه';
        });
      }
    } catch (e) {
      setState(() {
        _translatedText = 'خطا در اتصال به اینترنت';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // اضافه کردن کلمه به لغت‌نامه
  void _addToDictionary(String word) {
    final cleanWord = word.trim().replaceAll(RegExp(r'[^\w\u0600-\u06FF]'), '');
    if (cleanWord.isEmpty) return;

    if (!_dictionary.contains(cleanWord)) {
      setState(() {
        _dictionary.add(cleanWord);
      });
      _saveDictionary();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«$cleanWord» به لغت‌نامه اضافه شد'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«$cleanWord» قبلاً اضافه شده'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ساخت ویجت کلمات قابل کلیک
  Widget _buildClickableText(String text) {
    final words = text.split(RegExp(r'(\s+)'));

    return Wrap(
      spacing: 4,
      runSpacing: 8,
      children: words.map((word) {
        if (word.trim().isEmpty) return const SizedBox();
        return GestureDetector(
          onTap: () => _addToDictionary(word),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
            ),
            child: Text(
              word,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مترجم هوشمند + لغت‌نامه'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.book),
            tooltip: 'لغت‌نامه من',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DictionaryPage(
                    dictionary: _dictionary,
                    onUpdate: (newList) {
                      setState(() => _dictionary = newList);
                      _saveDictionary();
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // دکمه فعال‌سازی
            Card(
              elevation: 2,
              child: SwitchListTile(
                title: const Text(
                  'فعال‌سازی مترجم',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _isActive
                      ? 'مترجم روشن است - متن را وارد کنید'
                      : 'برای شروع ترجمه را روشن کنید',
                ),
                value: _isActive,
                activeThumbColor: Colors.green,
                onChanged: (value) {
                  setState(() => _isActive = value);
                  if (!value) {
                    _translatedText = '';
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // فیلد ورودی متن
            TextField(
              controller: _controller,
              maxLines: 5,
              enabled: _isActive,
              decoration: InputDecoration(
                hintText: _isActive
                    ? 'متن مورد نظر را اینجا بنویسید یا Paste کنید...'
                    : 'ابتدا مترجم را فعال کنید',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _isActive ? Colors.white : Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 12),

            // دکمه ترجمه
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActive && !_isLoading ? _translateText : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                label: Text(_isLoading ? 'در حال ترجمه...' : 'ترجمه به فارسی'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // نمایش ترجمه + کلمات قابل کلیک
            if (_translatedText.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'ترجمه (روی کلمات کلیک کنید تا به لغت‌نامه اضافه شوند):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: _buildClickableText(_translatedText),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// صفحه لغت‌نامه
class DictionaryPage extends StatefulWidget {
  final List<String> dictionary;
  final Function(List<String>) onUpdate;

  const DictionaryPage({
    super.key,
    required this.dictionary,
    required this.onUpdate,
  });

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  late List<String> _list;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.dictionary);
  }

  void _removeWord(int index) {
    setState(() {
      _list.removeAt(index);
    });
    widget.onUpdate(_list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('لغت‌نامه من (${_list.length})'),
        centerTitle: true,
      ),
      body: _list.isEmpty
          ? const Center(
              child: Text(
                'هنوز کلمه‌ای اضافه نکرده‌اید\nروی کلمات ترجمه کلیک کنید',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _list.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    _list[index],
                    style: const TextStyle(fontSize: 18),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeWord(index),
                  ),
                );
              },
            ),
    );
  }
}