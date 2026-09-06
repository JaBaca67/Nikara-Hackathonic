/// Minúsculas y sin tildes/diéresis, para que un buscador no dependa de que
/// quien escribe ponga los acentos correctos.
///
/// Nombres reales de negocios/jornadas en español están llenos de tildes
/// ("Rosquillería", "Limpieza de Río") y el teclado de un celular no siempre
/// las pone sola — un buscador que exige coincidencia exacta de acentos
/// devuelve "sin resultados" para una búsqueda que a simple vista debería
/// funcionar. `ñ`/`Ñ` se pliegan a `n` por el mismo motivo: preferible sobre-
/// encontrar que dejar a alguien sin poder buscar "Nicaragua" sin la tilde.
String normalizeForSearch(String input) {
  const accented = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = accented.indexOf(char);
    buffer.write(index == -1 ? char : plain[index]);
  }
  return buffer.toString();
}
