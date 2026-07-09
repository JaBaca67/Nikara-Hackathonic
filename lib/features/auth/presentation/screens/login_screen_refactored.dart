import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = constraints.maxHeight * 0.32;

            return Column(
              children: [
                SizedBox(
                  height: headerHeight,
                  child: _buildHeader(
                    width: constraints.maxWidth,
                    height: headerHeight,
                  ),
                ),
                Expanded(
                  child: _buildFormBody(width: constraints.maxWidth),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({required double width, required double height}) {
    return ClipRRect(
      child: Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.32, 0.00),
            end: Alignment(0.68, 1.00),
            colors: [Color(0xFFFDBE02), Color(0xFFF5A800), Color(0xFFE8A0B0)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -width * 0.1,
              top: height * 0.1,
              child: Container(
                width: 224,
                height: 224,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.50, 0.50),
                    radius: 0.71,
                    colors: [const Color(0x593A7D3A), Colors.black.withValues(alpha: 0)],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -width * 0.1,
              top: -32,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.50, 0.50),
                    radius: 0.71,
                    colors: [Colors.white.withValues(alpha: 0.25), Colors.black.withValues(alpha: 0)],
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width - 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
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
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: const Text(
                            'Nikara',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontFamily: 'Playfair Display',
                              fontWeight: FontWeight.w700,
                              height: 1.11,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Turismo comunitario en Nicaragua',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 14,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormBody({required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: const Text(
              'Bienvenido de nuevo',
              style: TextStyle(
                color: Color(0xFF1A1510),
                fontSize: 24,
                fontFamily: 'Playfair Display',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const Text(
                'Inicia sesión para continuar tu aventura',
                style: TextStyle(
                  color: Color(0xFF9A8A82),
                  fontSize: 14,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _buildInputField(
              label: 'CORREO ELECTRÓNICO',
              value: 'sofia@email.com',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildInputField(label: 'CONTRASEÑA', value: '••••••••••••'),
          ),
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
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
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
                  child: const Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          color: Color(0xFF1A1510),
                          fontSize: 16,
                          fontFamily: 'Playfair Display',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                Expanded(child: Container(height: 1, color: const Color(0x3FFDBE02))),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
                ),
                Expanded(child: Container(height: 1, color: const Color(0x3FFDBE02))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Row(
              children: [
                Expanded(
                  child: _buildSocialButton(
                    label: 'Google',
                    color: const Color(0xFFEA4335),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSocialButton(
                    label: 'Facebook',
                    color: const Color(0xFF1877F2),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '¿No tienes cuenta?',
                  style: TextStyle(
                    color: Color(0xFF9A8A82),
                    fontSize: 14,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Regístrate aquí',
                  style: TextStyle(
                    color: Color(0xFF3A7D3A),
                    fontSize: 16,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9A8A82),
            fontSize: 12,
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.50,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              shadows: const [
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
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1A1510),
                      fontSize: 16,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({required String label, required Color color}) {
    return Container(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadows: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF1A1510),
                      fontSize: 14,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
