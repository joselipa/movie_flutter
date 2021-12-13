import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:movies/helpers/debouncers.dart';
import 'package:movies/models/models.dart';
import 'package:movies/models/search_response.dart';

class MoviesProvider extends ChangeNotifier {
  final String _baseURL = 'api.themoviedb.org';
  final String _apiKey = 'd1f71cba29bd09d98eade07ea7fd2de6';
  final String _language = 'es-ES';

  List<Movie> onDisplayMovies = [];
  List<Movie> popularMovies = [];

  Map<int, List<Cast>> movieCast = {};

  int _page = 0;

  final debouncer = Debouncer(
    duration: Duration(milliseconds: 500),
  );

  final StreamController<List<Movie>> _suggestionStreamController =
      new StreamController.broadcast();

  Stream<List<Movie>> get suggestionStream =>
      this._suggestionStreamController.stream;

  MoviesProvider() {
    getOnDisplayMovies();
    getPopularMovies();
  }

  Future<String> _getJsonData(String endpoint, [int page = 1]) async {
    final url = Uri.https(
      _baseURL,
      endpoint,
      {
        'language': _language,
        'api_key': _apiKey,
        'page': '$page',
      },
    );
    final response = await http.get(url);
    return response.body;
  }

  getOnDisplayMovies() async {
    final jsonData = await _getJsonData('3/movie/now_playing');
    final nowPlayingResponse = NowPlayingResponse.fromJson(jsonData);
    onDisplayMovies = nowPlayingResponse.results;
    notifyListeners();
  }

  getPopularMovies() async {
    _page = _page + 1;
    final jsonData = await _getJsonData('3/movie/popular', _page);
    final popular = Popular.fromJson(jsonData);
    popularMovies = [...popularMovies, ...popular.results];
    notifyListeners();
  }

  Future<List<Cast>> getCasting(int movieId) async {
    if (movieCast.containsKey(movieId)) return movieCast[movieId]!;
    final jsonData = await _getJsonData('3/movie/$movieId/credits');
    final creditsResponse = CreditResponse.fromJson(jsonData);
    movieCast[movieId] = creditsResponse.cast;
    return creditsResponse.cast;
  }

  Future<List<Movie>> searchMovie(String query) async {
    final url = Uri.https(
      _baseURL,
      '3/search/movie',
      {
        'language': _language,
        'api_key': _apiKey,
        'query': '$query',
      },
    );
    final response = await http.get(url);
    final searchresponse = SearchResponse.fromJson(response.body);
    return searchresponse.results;
  }

  void getSuggestionByQuery(String searchTerm) {
    debouncer.value = '';
    debouncer.onValue = (value) async {
      final results = await this.searchMovie(value);
      this._suggestionStreamController.add(results);
    };
    final timer = Timer.periodic(Duration(milliseconds: 300), (timer) {
      debouncer.value = searchTerm;
    });
    Future.delayed(Duration(milliseconds: 301)).then((_) => timer.cancel());
  }
}
