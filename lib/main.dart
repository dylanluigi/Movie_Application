import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const baseUrl = 'https://api.themoviedb.org/3/movie/popular?api_key=965bad903c50ad13e17d1c22af35845f';
const searchBaseUrl = 'https://api.themoviedb.org/3/search/movie?api_key=965bad903c50ad13e17d1c22af35845f&query=';

void main() {
  runApp(MyApp());
}

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

class Actor {
  final String name;
  final String imageUrl;

  Actor({
    required this.name,
    required this.imageUrl,
  });

  factory Actor.fromJson(Map<String, dynamic> json) {
    return Actor(
      name: json['name'],
      imageUrl: 'https://image.tmdb.org/t/p/w500/${json["profile_path"]}',
    );
  }
}


class MovieDetailPage extends StatelessWidget {
  final Map<String, dynamic> movie;
  final Future<String> trailerKey;
  final MovieService movieService = MovieService(); // Initialize your movie service

  MovieDetailPage({Key? key, required this.movie, required this.trailerKey}) : super(key: key);

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
            SizedBox(height: 16.0),
            FutureBuilder<List<Actor>>(
              future: movieService.fetchActors(movie['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  final actors = snapshot.data ?? [];
                  return Container(
                    height: 130,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: actors.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              CircleAvatar(
                                backgroundImage: NetworkImage(actors[index].imageUrl),
                                radius: 40,
                              ),
                              SizedBox(height: 5),
                              Text(
                                actors[index].name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }
                return Center(child: CircularProgressIndicator());
              },
            ),
            SizedBox(height: 16.0),
            FutureBuilder<String>(
              future: trailerKey,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ElevatedButton(
                    child: const Text('Watch Trailer'),
                    onPressed: () async {
                      final url = 'https://www.youtube.com/watch?v=${snapshot.data}';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                  );
                } else {
                  return Container();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MovieService {
  final _client = http.Client();
  final String apiKey = '965bad903c50ad13e17d1c22af35845f';
  final String baseUrl = 'https://api.themoviedb.org/3';

  Future<String> fetchTrailer(int movieId) async {
     // replace with your own API key
    final response = await _client.get(Uri.parse('https://api.themoviedb.org/3/movie/$movieId/videos?api_key=$apiKey'));

    if (response.statusCode == 200) {
      var result = json.decode(response.body);
      for (var item in result['results']) {
        if (item['type'] == 'Trailer' && item['site'] == 'YouTube') {
          return item['key'];
        }
      }
    }

    return '';
  }

  Future<List<Actor>> fetchActors(int movieId) async {
    final response = await http.get(Uri.parse('$baseUrl/movie/$movieId/credits?api_key=$apiKey'));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      List<dynamic> jsonActors = jsonResponse['cast'];

      return jsonActors.map((json) => Actor.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load actors');
    }
  }


}

class MovieGrid extends StatelessWidget {
  final List<dynamic> data;
  final movieService = MovieService();
  final ScrollController scrollController;  // add this line
  MovieGrid({required this.data, required this.scrollController});  // modify this line

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
      ),
      controller: scrollController,  // add this line
      itemCount: data.length,
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailPage(
                  movie: data[index],
                  trailerKey: movieService.fetchTrailer(data[index]['id']),
                ),
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
  final ScrollController _scrollController = ScrollController();

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
          Expanded(child: MovieGrid(data: data, scrollController: _scrollController)), // modify this line
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

  Future<String> fetchTrailer(int movieId) async {
    String apiKey = '965bad903c50ad13e17d1c22af35845f'; // replace with your own API key
    final response = await _client.get(Uri.parse('https://api.themoviedb.org/3/movie/$movieId/videos?api_key=$apiKey'));

    if (response.statusCode == 200) {
      var result = json.decode(response.body);
      for (var item in result['results']) {
        if (item['type'] == 'Trailer' && item['site'] == 'YouTube') {
          return item['key'];
        }
      }
    }

    return '';
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
      body: MovieGrid(data: data, scrollController: _scrollController),
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
