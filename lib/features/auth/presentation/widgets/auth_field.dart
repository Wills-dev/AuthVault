import 'package:flutter/material.dart';

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.password = false,
    this.email = false,
    this.last = false,
    this.autofillHints,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool password;
  final bool email;
  final bool last;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;
  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool visible = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: widget.password && !visible,
      enableSuggestions: !widget.password,
      autocorrect: !widget.password && !widget.email,
      keyboardType: widget.email
          ? TextInputType.emailAddress
          : TextInputType.text,
      textCapitalization: widget.password || widget.email
          ? TextCapitalization.none
          : TextCapitalization.words,
      textInputAction: widget.last
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (widget.last) widget.onSubmitted?.call();
      },
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        errorMaxLines: 3,
        suffixIcon: widget.password
            ? IconButton(
                tooltip: visible
                    ? 'Hide ${widget.label.toLowerCase()}'
                    : 'Show ${widget.label.toLowerCase()}',
                onPressed: () => setState(() => visible = !visible),
                icon: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
    ),
  );
}
