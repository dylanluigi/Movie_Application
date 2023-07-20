import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'secrets.dart';

const baseUrl = 'https://api.themoviedb.org/3/movie/popular?api_key=${Secrets.API_KEY}';
const searchBaseUrl = 'https://api.themoviedb.org/3/search/movie?api_key=${Secrets.API_KEY}&query=';

Map<String, int> genreNameToId = {};

Future<void> fetchGenreMapping() async {
  final response = await http.get(Uri.parse('https://api.themoviedb.org/3/genre/movie/list?api_key=${Secrets.API_KEY}'));

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

class MovieProvider with ChangeNotifier {
  final _client = http.Client();
  List<dynamic> data = [];
  int currentPage = 1;

  Future<void> fetchData() async {
    try {
      final file = await DefaultCacheManager().getSingleFile("$baseUrl&page=$currentPage");
      if (await file.exists()) {
        final dataFromFile = await file.readAsString();
        data.addAll(json.decode(dataFromFile)['results']);
        currentPage++;
        notifyListeners(); // Notify listeners to update UI
      }
    } catch (e) {
      print(e);
    }
  }

  Future<String> fetchTrailer(int movieId) async {
    String apiKey = Secrets.API_KEY; // replace with your own API key
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
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MovieProvider(),
      child: MaterialApp(
        title: 'TMDB Movie App',
        theme: ThemeData(
          scaffoldBackgroundColor: Colors.grey[900],
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: HomePage(),
      ),
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
        backgroundColor: CupertinoColors.systemYellow,
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
  final String apiKey = Secrets.API_KEY;
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
    String apiKey = Secrets.API_KEY; // replace with your own API key
    final response = await _client.get(Uri.parse('https://api.themoviedb.org/3/movie/popular?api_key=$apiKey&page=$page'));

    if (response.statusCode == 200) {
      List<dynamic> results = json.decode(response.body)['results'];
      return results.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load movies');
    }
  }

  Future<List<String>> fetchGenres2() async {
    final response = await _client.get(Uri.parse('https://api.themoviedb.org/3/genre/movie/list?api_key=$apiKey'));

    if (response.statusCode == 200) {
      Map<String, dynamic> json = jsonDecode(response.body);
      List<dynamic> genresList = json['genres'];

      List<String> genres = [];
      for (var genre in genresList) {
        genres.add(genre['name']);
      }
      return genres;
    } else {
      throw Exception('Failed to load genres');
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

class _SearchPageState extends State<SearchPage> {
  String _selectedYear = 'All';  // set default value for year filter to 'All'
  String _selectedGenre = 'All'; // set default value for genre filter to 'All'
  final TextEditingController _controller = TextEditingController();
  final _client = http.Client();
  final ScrollController _scrollController = ScrollController();
  MovieService movieService = MovieService();
  List<String> genres = [];

  String get selectedYear => _selectedYear;
  set selectedYear(String value) {
    _selectedYear = value;
    if (_selectedYear == 'All' && _selectedGenre == 'All') {
      _controller.clear();
    }
    fetchMovies();
  }

  String get selectedGenre => _selectedGenre;
  set selectedGenre(String value) {
    _selectedGenre = value;
    if (_selectedYear == 'All' && _selectedGenre == 'All') {
      _controller.clear();
    }
    fetchMovies();
  }


  int currentPage = 1;  // Start from the first page
  int totalPage = 1; // Placeholder for total pages from API
  List<dynamic> data = [];

  @override
  void initState() {
    super.initState();
    fetchGenreMapping();  // fetch genre ID mappings
    fetchGenres();

    _controller.addListener(() {
      currentPage = 1;
      data = [];
      fetchMovies();
    });
  }

  Future<void> fetchMovies() async {
    while (currentPage <= totalPage) {
      try {
        String url;

        if (_selectedYear == 'All' && _selectedGenre == 'All') {
          // If both filters are 'All', fetch movies sorted by popularity
          url = _controller.text.isEmpty
              ? 'https://api.themoviedb.org/3/discover/movie?api_key=${Secrets.API_KEY}&sort_by=popularity.desc&page=$currentPage'
              : '$searchBaseUrl${_controller.text}&sort_by=popularity.desc&page=$currentPage';
        } else {
          // If any filter is set, fetch movies based on those filters
          final String genreParam = _selectedGenre != 'All' ? '&with_genres=${genreNameToId[_selectedGenre]}' : '';
          final String yearParam = _selectedYear != 'All' ? '&primary_release_year=$_selectedYear' : '';

          url = _controller.text.isEmpty
              ? 'https://api.themoviedb.org/3/discover/movie?api_key=${Secrets.API_KEY}&page=$currentPage$genreParam$yearParam'
              : '$searchBaseUrl${_controller.text}&page=$currentPage$genreParam$yearParam';
        }

        final response = await getApiResponse(url);

        if (response != null) {
          setState(() {
            data.addAll(response['results']);
            totalPage = response['total_pages']; // Update total page number
          });
        }

        // Check if we have fetched enough data to show
        if (data.length >= 10) {
          break;  // Stop fetching more data
        }

        currentPage++;
      } catch (e) {
        print(e);
      }
    }
  }



  Future<Map<String, dynamic>?> getApiResponse(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Failed to load data');
      return null;
    }
  }

  Future<void> fetchGenres() async {
    try {
      final genres = await movieService.fetchGenres2();
      setState(() {
        this.genres = genres;
        this.genres.insert(0, 'All');
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<String> years = List<String>.generate(DateTime.now().year - 1960 + 1, (i) => (1960 + i).toString());
    years.insert(0, 'All');

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemYellow,
        middle: Text('Search', style: TextStyle(color: Colors.white)),
      ),
      child: Container(
        color: Colors.grey[900],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CupertinoTextField(
                  controller: _controller,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: Colors.white,
                  ),
                  prefix: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    child: Icon(CupertinoIcons.search, color: Colors.grey),
                  ),
                  placeholder: 'Search',
                  placeholderStyle: TextStyle(color: Colors.grey),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CupertinoButton.filled(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemYellow, // Set the background color to yellow
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.film, size: 20, color: Colors.grey[900]), // Set the color to grey
                            SizedBox(width: 8),
                            Text(
                              'Genre: $selectedGenre',
                              style: TextStyle(color: Colors.grey[900]), // Set the color to grey
                            ),
                          ],
                        ),
                      ),
                      onPressed: () => showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => Container(
                          color: Colors.grey[850], // Set the background color of the scroll popup
                          height: 200,
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: genres.indexOf(selectedGenre),
                            ),
                            itemExtent: 32.0,
                            backgroundColor: Colors.grey[850], // Set the background color of the picker
                            onSelectedItemChanged: (index) {
                              setState(() {
                                selectedGenre = genres[index];
                                currentPage = 1;
                                data = [];
                              });
                            },
                            children: genres.map((genre) => Text(genre, style: TextStyle(color: Colors.white))).toList(), // Set the text color within the picker
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CupertinoButton.filled(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemYellow, // Set the background color to yellow
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.time, size: 20, color: Colors.grey[900]), // Set the color to grey
                            SizedBox(width: 8),
                            Text(
                              'Year: $selectedYear',
                              style: TextStyle(color: Colors.grey[900]), // Set the color to grey
                            ),
                          ],
                        ),
                      ),
                      onPressed: () => showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => Container(
                          color: Colors.grey[850], // Set the background color of the scroll popup
                          height: 200,
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: years.indexOf(selectedYear),
                            ),
                            itemExtent: 32.0,
                            backgroundColor: Colors.grey[850], // Set the background color of the picker
                            onSelectedItemChanged: (index) {
                              setState(() {
                                selectedYear = years[index];
                                currentPage = 1;
                                data = [];
                              });
                            },
                            children: years.map((year) => Text(year, style: TextStyle(color: Colors.white))).toList(), // Set the text color within the picker
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),
              Expanded(
                child: data.length == 0
                    ? Center(
                  child: CupertinoActivityIndicator(),
                )
                    : MovieGrid(data: data, scrollController: _scrollController),
              ),
            ],
          ),
        ),
      ),
    );
  }








}

class RandomMoviePage extends StatefulWidget {
  const RandomMoviePage({Key? key}) : super(key: key);

  @override
  _RandomMoviePageState createState() => _RandomMoviePageState();
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
    Provider.of<MovieProvider>(context, listen: false).fetchData();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        if (_scrollController.position.pixels != 0)
          fetchData();
      }
    });
    fetchData();
  }

  Future<String> fetchTrailer(int movieId) async {
    String apiKey = Secrets.API_KEY; // replace with your own API key
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

    if (randomMovieList.isNotEmpty) {
      // Randomly select a movie from the list
      var randomMovie = randomMovieList[Random().nextInt(randomMovieList.length)];

      // Call separate method to handle the Provider.of() call
      fetchTrailerAndUpdateState(randomMovie);
    }
  }

  void fetchTrailerAndUpdateState(Map<String, dynamic> randomMovie) async {
    final movieProvider = Provider.of<MovieProvider>(context, listen: false);
    var trailer = await movieProvider.fetchTrailer(randomMovie['id']);

    if(mounted) {
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


