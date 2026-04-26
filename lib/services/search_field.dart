// lib/widgets/search_field.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SearchField extends StatefulWidget {
  final Function(String) onSearch;
  final String? hint;
  final Duration debounceDelay;

  const SearchField({
    super.key,
    required this.onSearch,
    this.hint,
    this.debounceDelay = const Duration(milliseconds: 500),
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(widget.debounceDelay, () {
      widget.onSearch(_controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hint ?? 'Buscar...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onSearch('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
    );
  }
}
