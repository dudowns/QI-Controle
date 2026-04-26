// lib/hooks/infinite_scroll.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class InfiniteScroll extends StatefulWidget {
  final Future<List<dynamic>> Function(int page) loadMore;
  final Widget Function(dynamic item) itemBuilder;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final int pageSize;

  const InfiniteScroll({
    super.key,
    required this.loadMore,
    required this.itemBuilder,
    this.loadingWidget,
    this.emptyWidget,
    this.errorWidget,
    this.pageSize = 20,
  });

  @override
  State<InfiniteScroll> createState() => _InfiniteScrollState();
}

class _InfiniteScrollState extends State<InfiniteScroll> {
  final List<dynamic> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_isLoading || (!_hasMore && !reset)) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _items.clear();
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      }
    });

    try {
      final newItems = await widget.loadMore(_currentPage);
      setState(() {
        if (reset) {
          _items.clear();
        }
        _items.addAll(newItems);
        _hasMore = newItems.length >= widget.pageSize;
        if (_hasMore) _currentPage++;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _isLoading) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return widget.errorWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadInitial,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
    }

    if (_items.isEmpty) {
      return widget.emptyWidget ??
          const Center(
            child: Text('Nenhum item encontrado'),
          );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : null,
            ),
          );
        }
        return widget.itemBuilder(_items[index]);
      },
    );
  }

  void refresh() => _loadMore(reset: true);
}
