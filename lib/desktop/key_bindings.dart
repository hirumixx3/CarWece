import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform.dart';

/// Windows keyboard controls: action order and labels for the settings
/// screen, a pretty label for any key, and the capture row that rebinds
/// one action to the next key the player presses.
const keyActionOrder = <String>[
  'gas',
  'brake',
  'left',
  'right',
  'drift',
  'boost',
  'item',
  'super',
  'weapon',
  'target',
  'arsenal',
  'reset',
  'pause',
];

const keyActionLabels = <String, String>{
  'gas': 'Acelerar',
  'brake': 'Freio / ré',
  'left': 'Virar à esquerda',
  'right': 'Virar à direita',
  'drift': 'Drift',
  'boost': 'Turbo',
  'item': 'Usar item / atirar',
  'super': 'Supercarga (corrida)',
  'weapon': 'Trocar arma (batalha)',
  'target': 'Trocar mira (batalha)',
  'arsenal': 'Arsenal (batalha)',
  'reset': 'Repor carro',
  'pause': 'Pausar / voltar',
};

String prettyKeyLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.space) return 'ESPAÇO';
  if (key == LogicalKeyboardKey.escape) return 'ESC';
  if (key == LogicalKeyboardKey.shiftLeft) return 'SHIFT ESQ';
  if (key == LogicalKeyboardKey.shiftRight) return 'SHIFT DIR';
  if (key == LogicalKeyboardKey.controlLeft) return 'CTRL ESQ';
  if (key == LogicalKeyboardKey.controlRight) return 'CTRL DIR';
  if (key == LogicalKeyboardKey.altLeft) return 'ALT';
  if (key == LogicalKeyboardKey.arrowUp) return 'SETA ↑';
  if (key == LogicalKeyboardKey.arrowDown) return 'SETA ↓';
  if (key == LogicalKeyboardKey.arrowLeft) return 'SETA ←';
  if (key == LogicalKeyboardKey.arrowRight) return 'SETA →';
  if (key == LogicalKeyboardKey.enter) return 'ENTER';
  final label = key.keyLabel.trim();
  return label.isEmpty ? 'TECLA' : label.toUpperCase();
}

class KeyBindingRow extends StatefulWidget {
  final GameSettings settings;
  final String action;
  final VoidCallback onChanged;
  const KeyBindingRow({
    super.key,
    required this.settings,
    required this.action,
    required this.onChanged,
  });
  @override
  State<KeyBindingRow> createState() => _KeyBindingRowState();
}

class _KeyBindingRowState extends State<KeyBindingRow> {
  bool listening = false;

  bool _capture(KeyEvent event) {
    if (!listening) return false;
    if (event is KeyRepeatEvent) return true;
    if (event is! KeyDownEvent) return true;
    HardwareKeyboard.instance.removeHandler(_capture);
    final key = event.logicalKey;
    setState(() => listening = false);
    // Escape cancels the capture, except when Escape itself is the key
    // being assigned (the pause action).
    if (key != LogicalKeyboardKey.escape || widget.action == 'pause') {
      widget.settings.keyBindings[widget.action] = key;
      widget.onChanged();
    }
    return true;
  }

  void _startListening() {
    if (listening) return;
    setState(() => listening = true);
    HardwareKeyboard.instance.addHandler(_capture);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_capture);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.settings.keyFor(widget.action);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              keyActionLabels[widget.action] ?? widget.action,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xff0c192e),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: listening
                    ? const Color(0xffff8c3a)
                    : const Color(0xff3d5875),
              ),
            ),
            child: Text(
              listening ? 'PRESSIONE…' : prettyKeyLabel(current),
              style: TextStyle(
                fontSize: 12,
                color: listening
                    ? const Color(0xffff8c3a)
                    : const Color(0xfff3e9d2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: listening ? null : _startListening,
            child: Text(listening ? 'OUVINDO' : 'TROCAR'),
          ),
        ],
      ),
    );
  }
}
