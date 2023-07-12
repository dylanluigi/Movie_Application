import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';



class CustomCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'customCacheKey';

  CustomCacheManager()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
        ));

  static CustomCacheManager instance = CustomCacheManager();
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TMDB Movie App',
      theme: ThemeData(
        primaryColor: Colors.yellow,
        scaffoldBackgroundColor: Colors.grey[900],
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class MovieDetailPage extends StatelessWidget {
  final Map<String, dynamic> movie;

  const MovieDetailPage({Key? key, required this.movie}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        title: Text(movie['title']),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            CachedNetworkImage(
              imageUrl: 'https://image.tmdb.org/t/p/w500/${movie["poster_path"]}',
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              fit: BoxFit.cover,
              cacheManager: CustomCacheManager.instance,
            ),
            SizedBox(height: 16.0),
            Text(
              movie['title'],
              style: TextStyle(
                color: Colors.amber,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.0),
            Text(
              movie['overview'],
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class MovieGrid extends StatelessWidget {
  final List<dynamic> data;

  MovieGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
      ),
      itemCount: data.length,
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailPage(movie: data[index]),
              ),
            );
          },
          child: Card(
            color: const Color.fromARGB(255, 53, 52, 52),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: CachedNetworkImage(
                    imageUrl: 'https://image.tmdb.org/t/p/w500/${data[index]["poster_path"]}',
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                    fit: BoxFit.cover,
                    cacheManager: CustomCacheManager.instance,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    data[index]["title"],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}



class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String dropdownValue = 'Filter1';
  final TextEditingController _controller = TextEditingController();
  final _client = http.Client();
  List<dynamic> data = [];

  Future<void> searchMovies(String query) async {
    try {
      if (query.isNotEmpty) {
        final response = await _client.get(Uri.parse("$searchBaseUrl$query"));
        setState(() {
          data = json.decode(response.body)['results'];
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        title: Text('Search'),
        actions: [
          DropdownButton<String>(
            value: dropdownValue,
            icon: const Icon(Icons.arrow_downward),
            iconSize: 24,
            elevation: 16,
            style: const TextStyle(color: Colors.black),
            underline: Container(
              height: 2,
              color: Colors.black,
            ),
            onChanged: (String? newValue) {
              setState(() {
                dropdownValue = newValue!;
              });
            },
            items: <String>['Filter1', 'Filter2', 'Filter3', 'Filter4']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Search",
                hintText: "Search",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(25.0),
                  ),
                ),
              ),
              onChanged: (value) {
                // perform the search operation
                searchMovies(value);
              },
            ),
          ),
          Expanded(child: MovieGrid(data: data)),
        ],
      ),
    );
  }
}

class _HomePageState extends State<HomePage> {
  final _client = http.Client();
  List<dynamic> data = [];
  int currentPage = 1;
  int currentIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        fetchData();
      }
    });
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      final response = await _client.get(Uri.parse("$baseUrl&page=$currentPage"));
      setState(() {
        data.addAll(json.decode(response.body)['results']);
        currentPage++;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        title: const Text('Popular Movies'),
      ),
      body: MovieGrid(data: data),
            bottomNavigationBar: BottomNavigationBar(
               backgroundColor: Colors.grey[900],
               selectedItemColor: Colors.yellow,
               unselectedItemColor: Colors.white,
        currentIndex: currentIndex,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.movie),
            label: 'Movies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
        onTap: (index) {
          setState(() {
            currentIndex = index;
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SearchPage(),
                ),
              );
            }
          });
        },
      ),
    );
  }
}

