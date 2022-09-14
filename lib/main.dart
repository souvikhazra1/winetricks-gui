import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // theme
  static const _primaryColor = Colors.amber;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Winetricks GUI',
      theme: ThemeData(
        primarySwatch: _primaryColor,
        canvasColor: Colors.grey.shade900,
        dividerColor: Colors.grey.shade800,
        brightness: Brightness.dark,
        primaryColor: _primaryColor,
        fontFamily: 'OpenSans',
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Map<String, _Category> _categories = {};
  final List<_Package> _packages = [];
  final Map<String, List<_Package>> _filteredPackages = {};
  String _search = '';
  String _selected = '';
  String _winePrefix = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    var result = await Process.run('winetricks', ['list-all']);
    var output = result.stdout as String;
    var lines = output.split('\n');
    var cat = '';
    _categories['all'] = _Category(name: 'all');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        if (line.startsWith('=====')) {
          cat = line.replaceAll('=====', '').trim();
          if (cat != 'prefix') {
            _categories[cat] = _Category(name: cat);
          }
        } else {
          if (cat != 'prefix') {
            var idx = line.indexOf(' ');
            _packages.add(_Package(name: line.substring(0, idx), description: line.substring(idx).trim(), category: cat));
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _filter();
        _selected = 'all';
      });
    }
  }

  void _filter() {
    _search = _search.toLowerCase().trim();
    for (var c in _categories.values) {
      if (_filteredPackages.containsKey(c)) {
        _filteredPackages[c]?.clear();
      } else {
        _filteredPackages[c.name] = [];
      }
      c.itemCount = 0;
    }
    final List<_Package> allFilteredPackages = [];
    for (var package in _packages) {
      if (_search.isEmpty || package.name.contains(_search) || package.descriptionLower.contains(_search)) {
        _filteredPackages[package.category]?.add(package);
        allFilteredPackages.add(package);

        _categories[package.category]?.itemCount++;
      }
    }
    _filteredPackages['all'] = allFilteredPackages;
    _categories['all']!.itemCount = allFilteredPackages.length;
  }

  @override
  Widget build(BuildContext context) {
    final categoryList = _categories.values.toList(growable: false);
    final List<_Package> packages = _selected.isNotEmpty ? _filteredPackages[_selected] ?? [] : [];
    return Scaffold(
      body: categoryList.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Row(
              children: [
                SizedBox(
                  width: 240,
                  child: ListView.builder(
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: TextField(
                            decoration: const InputDecoration(border: UnderlineInputBorder(), hintText: 'Search', prefixIcon: Icon(Icons.search)),
                            onChanged: (value) => setState(() {
                              _search = value;
                              _filter();
                            }),
                          ),
                        );
                      } else {
                        final item = categoryList[index - 1];
                        final isSelected = item.name == _selected;
                        return ListTile(
                          title: Text("${item.nameDisplay} (${item.itemCount})"),
                          style: ListTileStyle.drawer,
                          selected: isSelected,
                          selectedColor: Theme.of(context).canvasColor,
                          selectedTileColor: Theme.of(context).primaryColor,
                          onTap: () => setState(() => _selected = item.name),
                        );
                      }
                    },
                    itemCount: categoryList.length + 1,
                  ),
                ),
                Container(width: 1, color: Theme.of(context).dividerColor),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        color: Theme.of(context).canvasColor,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(),
                            hintText: 'Wine Prefix',
                            prefixIcon: Padding(padding: EdgeInsets.only(right: 10, left: 10), child: Icon(Icons.folder_open)),
                          ),
                          onChanged: (value) => _winePrefix = value.trim(),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 800, mainAxisExtent: 90, crossAxisSpacing: 10, mainAxisSpacing: 10),
                            itemBuilder: (_, idx) {
                              var item = packages[idx];
                              return ListTile(
                                title: Text(item.name),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                                ),
                                shape: RoundedRectangleBorder(side: BorderSide(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(5)),
                                tileColor: item.description.contains('cached') ? Colors.white10 : Colors.transparent,
                                onTap: () {
                                  if (_winePrefix.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide Wine Prefix")));
                                  } else {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => _PackageInstallerWidget(package: item.name, prefix: _winePrefix),
                                    );
                                  }
                                },
                              );
                            },
                            itemCount: packages.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Package {
  final String name;
  final String description;
  late final String descriptionLower;
  final String category;

  _Package({required this.name, required this.description, required this.category}) {
    descriptionLower = description.toLowerCase();
  }
}

class _Category {
  final String name;
  late final String nameDisplay;
  int itemCount = 0;

  _Category({required this.name}) {
    nameDisplay = name[0].toUpperCase() + name.substring(1);
  }
}

class _PackageInstallerWidget extends StatefulWidget {
  const _PackageInstallerWidget({super.key, required this.package, required this.prefix});

  final String package;
  final String prefix;

  @override
  State<StatefulWidget> createState() => _PackageInstallerWidgetState();
}

class _PackageInstallerWidgetState extends State<_PackageInstallerWidget> {
  String _installLog = '';
  bool _completed = false;
  final _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    _install();
  }

  void _install() async {
    final p = await Process.start('winetricks', [widget.package], environment: {'WINEPREFIX': widget.prefix});
    p.stdout.listen(
      (data) {
        if (mounted) {
          setState(() {
            _installLog += String.fromCharCodes(data);
          });
        }
      },
      cancelOnError: true,
      onDone: () => setState(() => _completed = true),
      onError: (e) => setState(() {
        _completed = true;
        debugPrint(e);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    Future.delayed(Duration.zero, () => _sc.jumpTo(_sc.position.maxScrollExtent));
    return AlertDialog(
      title: Text('Installing ${widget.package}'),
      actions: [TextButton(onPressed: _completed ? () => Navigator.pop(context) : null, child: const Text("Close"))],
      contentPadding: const EdgeInsets.only(top: 16, left: 2, right: 2),
      content: Container(
        width: width > 500 ? width * 0.8 : width,
        height: double.infinity,
        color: Colors.black,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          controller: _sc,
          child: Text(_installLog),
        ),
      ),
    );
  }
}
