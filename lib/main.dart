import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:collection';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

const baseUrl = 'https://api.themoviedb.org/3/movie/popular?api_key=965bad903c50ad13e17d1c22af35845f';
const searchBaseUrl = 'https://api.themoviedb.org/3/search/movie?api_key=965bad903c50ad13e17d1c22af35845f&query=';

Map<String, int> genreNameToId = {};

Future<void> fetchGenreMapping() async {
  final response = await http.get(Uri.parse('https://api.themoviedb.org/3/genre/movie/list?api_key=965bad903c50ad13e17d1c22af35845f'));

  if (response.statusCode == 200) {
    final jsonResponse = json.decode(response.body);
    final List<dynamic> genresJson = jsonResponse['genres'];
    genresJson.forEach((genre) {
      genreNameToId[genre['name']] = genre['id'];
    });
  }
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

void main() {
  runApp(MaterialApp(
    home: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
  const HomePage({Key? key}) : super(key: key);

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
  final MovieService movieService = MovieService();

  MovieDetailPage({Key? key, required this.movie, required this.trailerKey})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        title: Text(movie['title']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MovieImage(movie: movie),
            const SizedBox(height: 16.0),
            MovieTitle(movie: movie),
            const SizedBox(height: 8.0),
            const Text(
              'Genres:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4.0),
            GenresBuilder(movieService: movieService, movie: movie),
            const SizedBox(height: 16.0),
            MovieReleaseDate(movie: movie),
            const SizedBox(height: 16.0),
            MovieOverview(movie: movie),
            const SizedBox(height: 16.0),
            ActorsBuilder(movieService: movieService, movie: movie),
            const SizedBox(height: 16.0),
            TrailerBuilder(trailerKey: trailerKey),
          ],
        ),
      ),
    );
  }
}

class MovieImage extends StatelessWidget {
  const MovieImage({
    Key? key,
    required this.movie,
  }) : super(key: key);

  final Map<String, dynamic> movie;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://image.tmdb.org/t/p/w500/${movie["poster_path"]}',
          ),
          fit: BoxFit.fitWidth,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
    );
  }
}

class MovieTitle extends StatelessWidget {
  const MovieTitle({
    Key? key,
    required this.movie,
  }) : super(key: key);

  final Map<String, dynamic> movie;

  @override
  Widget build(BuildContext context) {
    return Text(
      movie['title'],
      style: const TextStyle(
        color: Colors.amber,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class GenresBuilder extends StatelessWidget {
  const GenresBuilder({
    Key? key,
    required this.movieService,
    required this.movie,
  }) : super(key: key);

  final MovieService movieService;
  final Map<String, dynamic> movie;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: movieService.fetchGenres(movie['id']),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          final genres = snapshot.data!;
          return Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: genres
                .map(
                  (genre) => Chip(
                label: Text(
                  genre,
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.amber,
              ),
            )
                .toList(),
          );
        } else {
          return const Text(
            'Loading genres...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          );
        }
      },
    );
  }
}

class MovieReleaseDate extends StatelessWidget {
  const MovieReleaseDate({
    Key? key,
    required this.movie,
  }) : super(key: key);

  final Map<String, dynamic> movie;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Release Date: ${movie['release_date']}',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 16,
      ),
    );
  }
}

class MovieOverview extends StatelessWidget {
  const MovieOverview({
    Key? key,
    required this.movie,
  }) : super(key: key);

  final Map<String, dynamic> movie;

  @override
  Widget build(BuildContext context) {
    return Text(
      movie['overview'],
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),
    );
  }
}

class ActorsBuilder extends StatelessWidget {
  const ActorsBuilder({
    Key? key,
    required this.movieService,
    required this.movie,
  }) : super(key: key);

  final MovieService movieService;
  final Map<String, dynamic> movie;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Actor>>(
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
                      const SizedBox(height: 5),
                      Text(
                        actors[index].name,
                        style: const TextStyle(
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
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class TrailerBuilder extends StatelessWidget {
  const TrailerBuilder({
    Key? key,
    required this.trailerKey,
  }) : super(key: key);

  final Future<String> trailerKey;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: trailerKey,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.isNotEmpty) {
          final youtubePlayerController = YoutubePlayerController(
            initialVideoId: snapshot.data!,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
            ),
          );
          return YoutubePlayer(
            controller: youtubePlayerController,
            showVideoProgressIndicator: true,
            progressIndicatorColor: Colors.amber,
          );
        } else {
          return Container();
        }
      },
    );
  }
}

class MovieService {
  final _client = http.Client();
  final String apiKey = '965bad903c50ad13e17d1c22af35845f';
  final String baseUrl = 'https://api.themoviedb.org/3';
  Set<int> previousMovieIds;
  MovieService() : previousMovieIds = Set<int>();

  Future<List<String>> fetchGenres(int movieId) async {
    final response = await http.get(Uri.parse('$baseUrl/movie/$movieId?api_key=$apiKey'));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      List<dynamic> genreIds = jsonResponse['genres'];
      return genreIds.map((json) => json['name'].toString()).toList();
    } else {
      throw Exception('Failed to load genres');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMovieList(int page) async {
    String apiKey = '965bad903c50ad13e17d1c22af35845f'; // replace with your own API key
    final response = await _client.get(Uri.parse('https://api.themoviedb.org/3/movie/popular?api_key=$apiKey&page=$page'));

    if (response.statusCode == 200) {
      List<dynamic> results = json.decode(response.body)['results'];
      return results.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load movies');
    }
  }


  Future<Map<String, dynamic>> fetchRandomMovie({String? genre, String? year, String? minimumRating}) async {
    String apiUrl = '$baseUrl/discover/movie?api_key=$apiKey';

    if (genre != null) {
      apiUrl += '&with_genres=${genreNameToId[genre]}';
    }

    if (year != null) {
      apiUrl += '&primary_release_year=$year';
    }

    if (minimumRating != null) {
      apiUrl += '&vote_average.gte=$minimumRating';
    }

    final response = await _client.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      List<dynamic> allMovies = jsonResponse['results'];

      if (allMovies.isNotEmpty) {
        var movie = allMovies[Random().nextInt(allMovies.length)];

        // Check if movie has been fetched before, if so, fetch another
        while(previousMovieIds.contains(movie['id'])) {
          movie = allMovies[Random().nextInt(allMovies.length)];
        }
        previousMovieIds.add(movie['id']); // Add movie to previously fetched movies

        // fetch genres
        var genres = await fetchGenres(movie['id']);
        movie['genres'] = genres;

        return movie;
      }
    }


    throw Exception('Failed to load random movie');
  }


  Future<String> fetchTrailer(int movieId) async {
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
  final ScrollController scrollController;

  const MovieGrid({required this.data, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
      ),
      controller: scrollController,
      itemCount: data.length,
      itemBuilder: (BuildContext context, int index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieDetailPage(
                  movie: data[index],
                  trailerKey: MovieService().fetchTrailer(data[index]['id']),
                ),
              ),
            );
          },
          child: MovieCard(movie: data[index]),
        );
      },
    );
  }
}

class MovieCard extends StatelessWidget {
  final dynamic movie;

  const MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromARGB(255, 53, 52, 52),
      child: Column(
        children: <Widget>[
          Expanded(
            child: CachedNetworkImage(
              imageUrl: 'https://image.tmdb.org/t/p/w500/${movie["poster_path"]}',
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              fit: BoxFit.cover,
              cacheManager: CustomCacheManager.instance,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              movie["title"],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class RandomMoviePage extends StatefulWidget {
  const RandomMoviePage({Key? key}) : super(key: key);

  @override
  _RandomMoviePageState createState() => _RandomMoviePageState();
}

class _SearchPageState extends State<SearchPage> {
  String selectedYear = 'All';  // set default value for year filter to 'All'
  String selectedGenre = 'All'; // set default value for genre filter to 'All'
  final TextEditingController _controller = TextEditingController();
  final _client = http.Client();
  List<dynamic> data = [];
  final ScrollController _scrollController = ScrollController();

  Future<void> searchMovies(String query) async {
    try {
      if (query.isNotEmpty) {
        final response = await _client.get(Uri.parse("$searchBaseUrl$query"));
        List<dynamic> allData = json.decode(response.body)['results'];

        // Apply the filters
        setState(() {
          data = allData.where((movie) {
            final releaseYear = movie['release_date'].isNotEmpty ? DateTime.parse(movie['release_date']).year : null;
            final genreIds = movie['genre_ids'] as List<dynamic>;

            // Checks if the movie's release year is equal or later than the selected year and if the movie's genres contain the selected genre
            return (selectedYear == 'All' || (releaseYear != null && releaseYear >= int.parse(selectedYear))) &&
                (selectedGenre == 'All' || genreIds.contains(genreNameToId[selectedGenre]));
          }).toList();
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      searchMovies(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> years = List<String>.generate(DateTime.now().year - 1990 + 1, (i) => (1990 + i).toString());
    years.insert(0, 'All');

    List<String> genres = genreNameToId.keys.toList();
    genres.insert(0, 'All');

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemYellow,
        middle: Text('Search'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoPicker(
              itemExtent: 32.0,
              onSelectedItemChanged: (index) {
                setState(() {
                  selectedYear = years[index];
                  searchMovies(_controller.text);
                });
              },
              children: years.map((year) => Text(year)).toList(),
            ),
            SizedBox(width: 8.0),
            CupertinoPicker(
              itemExtent: 32.0,
              onSelectedItemChanged: (index) {
                setState(() {
                  selectedGenre = genres[index];
                  searchMovies(_controller.text);
                });
              },
              children: genres.map((genre) => Text(genre)).toList(),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CupertinoSearchTextField(
              controller: _controller,
            ),
          ),
          Expanded(child: MovieGrid(data: data, scrollController: _scrollController)),
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
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.darkBackgroundGray,
        activeColor: CupertinoColors.systemYellow,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.film),
            label: 'Movies',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.shuffle),
            label: 'Random',
          ),
        ],
      ),
      tabBuilder: (BuildContext context, int index) {
        switch (index) {
          case 0:
            return CupertinoTabView(
              builder: (context) {
                return CupertinoPageScaffold(
                  navigationBar: CupertinoNavigationBar(
                    backgroundColor: CupertinoColors.systemYellow,
                    middle: const Text('Popular Movies'),
                  ),
                  child: MovieGrid(data: data, scrollController: _scrollController),
                );
              },
            );
          case 1:
            return CupertinoTabView(
              builder: (context) {
                return const SearchPage();
              },
            );
          case 2:
            return CupertinoTabView(
              builder: (context) {
                return const RandomMoviePage();
              },
            );
          default:
            return CupertinoTabView(
              builder: (context) {
                return CupertinoPageScaffold(
                  navigationBar: CupertinoNavigationBar(
                    backgroundColor: CupertinoColors.systemYellow,
                    middle: const Text('Popular Movies'),
                  ),
                  child: MovieGrid(data: data, scrollController: _scrollController),
                );
              },
            );
        }
      },
    );
  }
}

class _RandomMoviePageState extends State<RandomMoviePage> {
  final MovieService movieService = MovieService();
  Map<String, dynamic>? movie;
  String? trailerKey;

  @override
  void initState() {
    super.initState();
    fetchRandomMovie();
  }

  void fetchRandomMovie() async {
    // Randomly generate a page number
    var randomPage = Random().nextInt(500); // 500 can be replaced by the maximum number of pages you know exists in TMDB
    var randomMovieList = await movieService.fetchMovieList(randomPage);

    if (randomMovieList != null && randomMovieList.isNotEmpty) {
      // Randomly select a movie from the list
      var randomMovie = randomMovieList[Random().nextInt(randomMovieList.length)];
      var trailer = await movieService.fetchTrailer(randomMovie['id']);

      setState(() {
        movie = randomMovie;
        trailerKey = trailer;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemYellow,
        middle: const Text('Random Movie'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.shuffle, size: 28),
          onPressed: fetchRandomMovie,
        ),
      ),
      child: movie == null
          ? const Center(child: CupertinoActivityIndicator())
          : MovieDetailPage(movie: movie!, trailerKey: Future.value(trailerKey)),
    );
  }
}




