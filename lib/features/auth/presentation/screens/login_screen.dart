import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); 
  
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  
  // 1. DECLARACIONES (Van sueltas al principio de la clase)
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();



  // 2. MÉTODO DISPOSE (Debe tener su propia función con llaves)
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose(); // El 'super' solo es válido adentro de funciones como esta
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final headerHeight = screenHeight * 0.45;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerHeight,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0.32, 0.00),
                  end: Alignment(0.68, 1.00),
                  colors: [
                    Color(0xFFFDBE02),
                    Color(0xFFF5A800),
                    Color(0xFFE8A0B0),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -90,
                    top: headerHeight * 0.18,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(0.50, 0.50),
                          radius: 0.72,
                          colors: [
                            const Color(0x593A7D3A),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -70,
                    top: -20,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(0.50, 0.50),
                          radius: 0.72,
                          colors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: headerHeight * 0.18),
                  _buildLogo(),
                  const SizedBox(height: 24),
                  _buildFormBody(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: ShapeDecoration(
            color: Colors.white.withValues(alpha: 0.30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 6,
                offset: Offset(0, 4),
                spreadRadius: -4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NIKARA',
          style: GoogleFonts.playfairDisplaySc(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildFormBody() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // 🌟 TRUCO 1: Degradado con "Stops" para crear la sombra interna superior (Bisel)
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(
              0xFFE0D0B8,
            ), // El tono oscuro que simula el "hundimiento" del borde
            Color(0xFFFFF9F0), // Tu color crema original
          ],
          stops: [
            0.0,
            0.08,
          ], // El efecto oscuro solo ocupará el primer 8% de la tarjeta arriba
        ),

        borderRadius: BorderRadius.circular(40),

        // 🌟 TRUCO 2: Borde uniforme que simula el grosor del material de la tarjeta
        border: Border.all(color: const Color(0xFFF3E5D0), width: 2.0),

        // 🌟 TRUCO 3: Las 3 Capas de Sombras para la profundidad física
        boxShadow: [
          // Capa 1: Sombra Ambiental (Gigante y suave para despegar la tarjeta del fondo amarillo)
          const BoxShadow(
            color: Color(0x1A000000), // 10% de opacidad
            blurRadius: 36,
            offset: Offset(0, 20), // Empuja la sombra bastante hacia abajo
          ),

          // Capa 2: Sombra Direccional (Más nítida, le da peso y define la base)
          const BoxShadow(
            color: Color(0x21000000), // 13% de opacidad
            blurRadius: 12,
            offset: Offset(0, 6),
          ),

          // Capa 3: Brillo de Contraste (Sombra blanca que sale hacia ARRIBA)
          // Esto hace que el borde superior resalte brutalmente contra el fondo
          BoxShadow(
            color: const Color.fromARGB(
              255,
              196,
              189,
              189,
            ).withValues(alpha: 0.65),
            blurRadius: 10,
            offset: const Offset(0, -5), // Se proyecta hacia arriba
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido de nuevo',
              style: GoogleFonts.leagueSpartan(
                color: Color(0xFF1A1510),
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inicia sesión para continuar tu aventura',
              style: TextStyle(
                color: Color.fromRGBO(154, 138, 130, 1),
                fontSize: 14,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 20),
            _buildInputField(
              label: 'Correo electrónico',
              hintText: 'bugnuelitos@email.com',
              controller: emailController,
            ),
            const SizedBox(height: 14),
            _buildInputField(
              label: 'Contraseña', 
              hintText: '•••••••••••••',
              controller: passwordController),
          
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                    color: Color(0xFF3A7D3A),
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 56,
              decoration: ShapeDecoration(
                gradient: const LinearGradient(
                  begin: Alignment(0.00, 0.00),
                  end: Alignment(1.00, 1.00),
                  colors: [Color(0xFFFDBE02), Color(0xFFF5A800)],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadows: const [
                  BoxShadow(
                    color: Color(0x66FDBE02),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {},
                  child: Center(
                    child: Text(
                      'Iniciar Sesión',
                      style: GoogleFonts.leagueSpartan(
                        color: Color(0xFF1A1510),
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28), // Espacio después del botón
            _buildSocialSection(), // Sección "o continúa con" y los logos
            const SizedBox(height: 24), // Espacio antes del registro
            _buildRegisterPrompt(), // Texto "¿No tienes cuenta? Regístrate"
          ],
        ),
      ),
    );
  }

  Widget _buildSocialSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(height: 1.5, color: const Color(0x3FFDBE02)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o continúa con',
                style: TextStyle(
                  color: Color(0xFFC4B8B0),
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Container(height: 1.5, color: const Color(0x3FFDBE02)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialCircle(
              icon: FontAwesomeIcons.google,
              color: const Color(0xFFEA4335),
            ),
            const SizedBox(width: 16),

            _buildSocialCircle(
              icon: FontAwesomeIcons.apple,
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
            const SizedBox(width: 16),
            _buildSocialCircle(
              icon: FontAwesomeIcons.facebook,
              color: const Color(0xFF1877F2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '¿No tienes cuenta?',
          style: TextStyle(
            color: Color(0xFF9A8A82),
            fontSize: 14,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w400,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Regístrate aquí',
            style: TextStyle(
              color: Color(0xFF3A7D3A),
              fontSize: 15,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({required String label, required String hintText, required TextEditingController controller,
  bool isPassword = false,
  }) {
    return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF9A8A82),
          fontSize: 10,
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.50,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Reduje el padding vertical porque TextField ya tiene el suyo
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),      
          // 1. 🎨 AQUÍ AGREGAMOS EL DELINEADO (Borde)
          border: Border.all(
            color: const Color.fromARGB(255, 121, 99, 65), // Color del borde (un crema oscuro/café claro)
            width: 1, // Grosor del delineado
          ),
          
          boxShadow: const [
            BoxShadow(
              color: Color(0x0CFDBE02),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(width: 20, height: 20, color: Colors.grey.shade300),
            const SizedBox(width: 12),
            Expanded(
              // 2. ⌨️ AQUÍ CAMBIAMOS EL TEXTO ESTÁTICO POR UN CAMPO EDITABLE
              child: TextField(
                controller: controller, // Conectamos el controlador para guardar el texto
                obscureText: isPassword, // Si es true, pondrá "••••••••"
                style: const TextStyle(
                  color: Color(0xFF1A1510),
                  fontSize: 14,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: hintText, // El texto gris que aparece cuando está vacío
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none, // Le quitamos la línea fea que trae por defecto
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildSocialCircle({required dynamic icon, required Color color}) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: FaIcon(
          icon,
          color: color,
          size: 20, // Tamaño ideal para que se vea elegante
        ),
      ),
    );
  }
}
