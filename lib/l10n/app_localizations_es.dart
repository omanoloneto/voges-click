// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get fileMenu => 'Archivo';

  @override
  String get newImage => 'Nuevo';

  @override
  String get openImage => 'Abrir';

  @override
  String get save => 'Guardar';

  @override
  String get saveAs => 'Guardar como';

  @override
  String saveAsFormat(String format) {
    return 'Guardar como $format';
  }

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Idioma del sistema';

  @override
  String get minimize => 'Minimizar';

  @override
  String get maximize => 'Maximizar';

  @override
  String get restore => 'Restaurar';

  @override
  String get close => 'Cerrar';

  @override
  String get untitled => 'Sin título';

  @override
  String get undo => 'Deshacer';

  @override
  String get redo => 'Rehacer';

  @override
  String get copy => 'Copiar';

  @override
  String get cut => 'Cortar';

  @override
  String get paste => 'Pegar';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deleteSelection => 'Borrar selección';

  @override
  String get crop => 'Recortar';

  @override
  String get resize => 'Cambiar tamaño';

  @override
  String get rotateLeft => 'Girar a la izquierda';

  @override
  String get rotateRight => 'Girar a la derecha';

  @override
  String get flipHorizontal => 'Voltear horizontalmente';

  @override
  String get flipVertical => 'Voltear verticalmente';

  @override
  String get toolPencil => 'Lápiz';

  @override
  String get toolBrush => 'Pincel';

  @override
  String get toolEraser => 'Borrador';

  @override
  String get toolFill => 'Relleno con color';

  @override
  String get toolPicker => 'Selector de color';

  @override
  String get toolLine => 'Línea';

  @override
  String get toolRectangle => 'Rectángulo';

  @override
  String get toolEllipse => 'Elipse';

  @override
  String get shapeOutline => 'Contorno';

  @override
  String get shapeFilled => 'Rellena';

  @override
  String get swapColors => 'Intercambiar colores';

  @override
  String get editColors => 'Editar colores';

  @override
  String get editColorTitle => 'Editar color';

  @override
  String get red => 'Rojo';

  @override
  String get green => 'Verde';

  @override
  String get blue => 'Azul';

  @override
  String get hexColor => 'Hex';

  @override
  String sizePixels(int size) {
    return '$size px';
  }

  @override
  String get brushSize => 'Tamaño';

  @override
  String get newImageTitle => 'Nueva imagen';

  @override
  String get width => 'Ancho';

  @override
  String get height => 'Alto';

  @override
  String get pixelsUnit => 'px';

  @override
  String get create => 'Crear';

  @override
  String get resizeTitle => 'Cambiar tamaño de la imagen';

  @override
  String get keepProportions => 'Mantener las proporciones';

  @override
  String get stretchDrawing => 'Estirar el dibujo';

  @override
  String get stretchDrawingHint =>
      'Desactivado: solo el lienzo crece o se reduce, y el dibujo queda del mismo tamaño.';

  @override
  String sizeLimit(int max) {
    return 'Entre 1 y $max px.';
  }

  @override
  String get apply => 'Aplicar';

  @override
  String get ok => 'Aceptar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get saveChangesTitle => '¿Guardar los cambios?';

  @override
  String saveChangesMessage(String name) {
    return '¿Quieres guardar los cambios en \"$name\"?';
  }

  @override
  String get dontSave => 'No guardar';

  @override
  String get unsavedChanges => 'Cambios sin guardar';

  @override
  String get openImageTitle => 'Abrir imagen';

  @override
  String get saveImageTitle => 'Guardar imagen';

  @override
  String get openFailed => 'No se pudo abrir este archivo como imagen.';

  @override
  String get saveFailed => 'No se pudo guardar la imagen.';

  @override
  String imageTooLarge(int max) {
    return 'Esta imagen es demasiado grande. El límite es $max px por lado.';
  }

  @override
  String get nothingToPaste => 'No hay ninguna imagen para pegar.';

  @override
  String get copyFailed => 'No se pudo copiar la imagen.';

  @override
  String cursorPosition(int x, int y) {
    return '$x, $y px';
  }

  @override
  String imageSize(int width, int height) {
    return '$width × $height px';
  }

  @override
  String selectionSize(int width, int height) {
    return 'Selección: $width × $height px';
  }

  @override
  String get zoom => 'Zoom';

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'Alejar';

  @override
  String get fitToWindow => 'Ajustar a la ventana';

  @override
  String get backgroundLayer => 'Fondo';

  @override
  String layerNumber(int number) {
    return 'Capa $number';
  }

  @override
  String toolWithKey(String name, String key) {
    return '$name ($key)';
  }

  @override
  String get toolMove => 'Mover';

  @override
  String get toolMarquee => 'Selección rectangular';

  @override
  String get toolEllipseMarquee => 'Selección elíptica';

  @override
  String get toolLasso => 'Lazo';

  @override
  String get toolCrop => 'Recortar';

  @override
  String get toolGradient => 'Degradado';

  @override
  String get toolText => 'Texto';

  @override
  String get toolHand => 'Mano';

  @override
  String get toolZoom => 'Zoom';

  @override
  String get foregroundColor => 'Color frontal';

  @override
  String get backgroundColor => 'Color de fondo';

  @override
  String get defaultColors => 'Negro y blanco';

  @override
  String get menuImage => 'Imagen';

  @override
  String get menuLayer => 'Capa';

  @override
  String get menuSelect => 'Selección';

  @override
  String get menuAdjustments => 'Ajustes';

  @override
  String get resizeImage => 'Cambiar tamaño…';

  @override
  String get cropToSelection => 'Recortar a la selección';

  @override
  String get flattenImage => 'Acoplar imagen';

  @override
  String get newLayer => 'Nueva capa';

  @override
  String get duplicateLayer => 'Duplicar capa';

  @override
  String get deleteLayer => 'Eliminar capa';

  @override
  String get renameLayer => 'Cambiar nombre de la capa…';

  @override
  String get mergeDown => 'Combinar hacia abajo';

  @override
  String get raiseLayer => 'Traer adelante';

  @override
  String get lowerLayer => 'Enviar atrás';

  @override
  String get deselect => 'Deseleccionar';

  @override
  String get invertSelection => 'Invertir selección';

  @override
  String get fillSelection => 'Rellenar con el color frontal';

  @override
  String get brightnessContrast => 'Brillo y contraste…';

  @override
  String get hueSaturation => 'Tono y saturación…';

  @override
  String get invertColors => 'Invertir colores';

  @override
  String get grayscale => 'Escala de grises';

  @override
  String get brightness => 'Brillo';

  @override
  String get contrast => 'Contraste';

  @override
  String get hue => 'Tono';

  @override
  String get saturation => 'Saturación';

  @override
  String get layersPanel => 'Capas';

  @override
  String get colorPanel => 'Color';

  @override
  String get swatchHint => 'Clic: frontal. Clic derecho: fondo.';

  @override
  String get opacity => 'Opacidad';

  @override
  String get blendMode => 'Modo de fusión';

  @override
  String get showLayer => 'Mostrar capa';

  @override
  String get hideLayer => 'Ocultar capa';

  @override
  String get hardness => 'Dureza';

  @override
  String get tolerance => 'Tolerancia';

  @override
  String percent(int value) {
    return '$value %';
  }

  @override
  String get hiddenLayerHint => 'La capa activa está oculta.';

  @override
  String get cancelCrop => 'Cancelar recorte';

  @override
  String get applyCrop => 'Aplicar recorte';

  @override
  String get textTitle => 'Texto';

  @override
  String get textHint => 'Escribe el texto';

  @override
  String get fontSize => 'Tamaño';

  @override
  String get bold => 'Negrita';

  @override
  String get renameLayerTitle => 'Cambiar nombre de la capa';

  @override
  String get layerNameLabel => 'Nombre';

  @override
  String get psdSimplified =>
      'Algunas cosas de este PSD (grupos, máscaras, efectos o texto editable) se simplificaron. Guardar no toca el original y pide un archivo nuevo.';

  @override
  String get psdOpenedFlat =>
      'Este tipo de PSD se abre como una sola capa. Guardar no toca el original y pide un archivo nuevo.';

  @override
  String exportedCopy(String format) {
    return 'Se guardó una copia acoplada en $format. Guarda como PSD para conservar las capas.';
  }

  @override
  String get blendNormal => 'Normal';

  @override
  String get blendDarken => 'Oscurecer';

  @override
  String get blendMultiply => 'Multiplicar';

  @override
  String get blendColorBurn => 'Subexponer color';

  @override
  String get blendLighten => 'Aclarar';

  @override
  String get blendScreen => 'Trama';

  @override
  String get blendColorDodge => 'Sobreexponer color';

  @override
  String get blendLinearDodge => 'Sobreexposición lineal (añadir)';

  @override
  String get blendOverlay => 'Superponer';

  @override
  String get blendSoftLight => 'Luz suave';

  @override
  String get blendHardLight => 'Luz fuerte';

  @override
  String get blendDifference => 'Diferencia';

  @override
  String get blendExclusion => 'Exclusión';

  @override
  String get blendHue => 'Tono';

  @override
  String get blendSaturation => 'Saturación';

  @override
  String get blendColor => 'Color';

  @override
  String get blendLuminosity => 'Luminosidad';
}
