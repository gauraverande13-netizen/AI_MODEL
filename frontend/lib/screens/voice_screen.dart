import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  String _text = 'Tap the mic to speak...';
  String _aiResponse = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-IN"); // Hindi accent
    await _flutterTts.setSpeechRate(0.7);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done') {
            setState(() => _isListening = false);
            _controller.stop();
            _controller.reset();
            if (_text.isNotEmpty && _text != 'Tap the mic to speak...') {
              _sendToAI(_text);
            }
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
          _controller.stop();
          _controller.reset();
        },
      );
      
      if (available) {
        setState(() {
          _isListening = true;
          _text = '';
          _aiResponse = '';
        });
        _controller.repeat(reverse: true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _controller.stop();
      _controller.reset();
      _speech.stop();
      if (_text.isNotEmpty && _text != 'Tap the mic to speak...') {
        _sendToAI(_text);
      }
    }
  }

  Future<void> _sendToAI(String message) async {
    setState(() {
      _aiResponse = 'Thinking...';
    });
    try {
      final res = await ApiService.sendMessage(message);
      setState(() {
        _aiResponse = res.reply;
      });
      _speak(res.reply);
    } catch (e) {
      setState(() {
        _aiResponse = 'Server connection failed.';
      });
      _speak("Sorry, server connection failed.");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        // AI Response Text
        if (_aiResponse.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _aiResponse,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.secondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          const Spacer(),
          
        const SizedBox(height: 20),
        
        // Mic Button
        GestureDetector(
          onTap: _listen,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 140 + (_controller.value * 25),
                  height: 140 + (_controller.value * 25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isListening 
                          ? AppTheme.primary.withOpacity(0.4)
                          : Colors.transparent,
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: _isListening
                          ? AppTheme.secondary.withOpacity(0.3)
                          : Colors.transparent,
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                    gradient: LinearGradient(
                      colors: _isListening 
                        ? [AppTheme.primary, AppTheme.secondary]
                        : [Colors.grey.shade800, Colors.grey.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        const SizedBox(height: 40),
        
        // Recognized text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ),
        
        const Spacer(),
        
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              _buildQuickChip("⚡ USD to INR rate?"),
              _buildQuickChip("🕒 Current time in sangamner?"),
              _buildQuickChip("🚀 Who are you?"),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildQuickChip(String label) {
    return GestureDetector(
      onTap: () {
        if (!_isListening) {
          setState(() {
            _text = label.replaceAll('⚡ ', '').replaceAll('🕒 ', '').replaceAll('🚀 ', '');
          });
          _sendToAI(_text);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }
}
