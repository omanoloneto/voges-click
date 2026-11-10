// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get fileMenu => 'Arquivo';

  @override
  String get newImage => 'Novo';

  @override
  String get openImage => 'Abrir';

  @override
  String get save => 'Salvar';

  @override
  String get saveAs => 'Salvar como';

  @override
  String saveAsFormat(String format) {
    return 'Salvar como $format';
  }

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Idioma do sistema';

  @override
  String get minimize => 'Minimizar';

  @override
  String get maximize => 'Maximizar';

  @override
  String get restore => 'Restaurar';

  @override
  String get close => 'Fechar';

  @override
  String get untitled => 'Sem título';

  @override
  String get undo => 'Desfazer';

  @override
  String get redo => 'Refazer';

  @override
  String get copy => 'Copiar';

  @override
  String get cut => 'Recortar';

  @override
  String get paste => 'Colar';

  @override
  String get selectAll => 'Selecionar tudo';

  @override
  String get deleteSelection => 'Apagar seleção';

  @override
  String get crop => 'Cortar';

  @override
  String get resize => 'Redimensionar';

  @override
  String get rotateLeft => 'Girar para a esquerda';

  @override
  String get rotateRight => 'Girar para a direita';

  @override
  String get flipHorizontal => 'Espelhar na horizontal';

  @override
  String get flipVertical => 'Espelhar na vertical';

  @override
  String get toolPencil => 'Lápis';

  @override
  String get toolBrush => 'Pincel';

  @override
  String get toolEraser => 'Borracha';

  @override
  String get toolFill => 'Balde de tinta';

  @override
  String get toolPicker => 'Conta-gotas';

  @override
  String get toolLine => 'Linha';

  @override
  String get toolRectangle => 'Retângulo';

  @override
  String get toolEllipse => 'Elipse';

  @override
  String get shapeOutline => 'Contorno';

  @override
  String get shapeFilled => 'Preenchida';

  @override
  String get swapColors => 'Trocar as cores';

  @override
  String get editColors => 'Editar cores';

  @override
  String get editColorTitle => 'Editar cor';

  @override
  String get red => 'Vermelho';

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
  String get brushSize => 'Tamanho';

  @override
  String get newImageTitle => 'Nova imagem';

  @override
  String get width => 'Largura';

  @override
  String get height => 'Altura';

  @override
  String get pixelsUnit => 'px';

  @override
  String get create => 'Criar';

  @override
  String get resizeTitle => 'Redimensionar imagem';

  @override
  String get keepProportions => 'Manter as proporções';

  @override
  String get stretchDrawing => 'Esticar o desenho';

  @override
  String get stretchDrawingHint =>
      'Desligado: só a tela cresce ou diminui, e o desenho fica do mesmo tamanho.';

  @override
  String sizeLimit(int max) {
    return 'Entre 1 e $max px.';
  }

  @override
  String get apply => 'Aplicar';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get saveChangesTitle => 'Salvar as alterações?';

  @override
  String saveChangesMessage(String name) {
    return 'Quer salvar as alterações em \"$name\"?';
  }

  @override
  String get dontSave => 'Não salvar';

  @override
  String get unsavedChanges => 'Alterações não salvas';

  @override
  String get openImageTitle => 'Abrir imagem';

  @override
  String get saveImageTitle => 'Salvar imagem';

  @override
  String get openFailed => 'Não foi possível abrir este arquivo como imagem.';

  @override
  String get saveFailed => 'Não foi possível salvar a imagem.';

  @override
  String imageTooLarge(int max) {
    return 'Esta imagem é grande demais. O limite é $max px por lado.';
  }

  @override
  String get nothingToPaste => 'Não há imagem para colar.';

  @override
  String get copyFailed => 'Não foi possível copiar a imagem.';

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
    return 'Seleção: $width × $height px';
  }

  @override
  String get zoom => 'Zoom';

  @override
  String get zoomIn => 'Aumentar o zoom';

  @override
  String get zoomOut => 'Diminuir o zoom';

  @override
  String get fitToWindow => 'Ajustar à janela';

  @override
  String get backgroundLayer => 'Fundo';

  @override
  String layerNumber(int number) {
    return 'Camada $number';
  }

  @override
  String toolWithKey(String name, String key) {
    return '$name ($key)';
  }

  @override
  String get toolMove => 'Mover';

  @override
  String get toolMarquee => 'Seleção retangular';

  @override
  String get toolEllipseMarquee => 'Seleção elíptica';

  @override
  String get toolLasso => 'Laço';

  @override
  String get toolCrop => 'Cortar';

  @override
  String get toolGradient => 'Degradê';

  @override
  String get toolText => 'Texto';

  @override
  String get toolHand => 'Mão';

  @override
  String get toolZoom => 'Zoom';

  @override
  String get foregroundColor => 'Cor de primeiro plano';

  @override
  String get backgroundColor => 'Cor de fundo';

  @override
  String get defaultColors => 'Preto e branco';

  @override
  String get menuImage => 'Imagem';

  @override
  String get menuLayer => 'Camada';

  @override
  String get menuSelect => 'Seleção';

  @override
  String get menuAdjustments => 'Ajustes';

  @override
  String get resizeImage => 'Redimensionar…';

  @override
  String get cropToSelection => 'Cortar na seleção';

  @override
  String get flattenImage => 'Achatar imagem';

  @override
  String get newLayer => 'Nova camada';

  @override
  String get duplicateLayer => 'Duplicar camada';

  @override
  String get deleteLayer => 'Excluir camada';

  @override
  String get renameLayer => 'Renomear camada…';

  @override
  String get freeTransform => 'Transformação livre';

  @override
  String get mergeDown => 'Mesclar para baixo';

  @override
  String get raiseLayer => 'Trazer para frente';

  @override
  String get lowerLayer => 'Enviar para trás';

  @override
  String get deselect => 'Desfazer seleção';

  @override
  String get invertSelection => 'Inverter seleção';

  @override
  String get fillSelection => 'Preencher com a cor de primeiro plano';

  @override
  String get brightnessContrast => 'Brilho e contraste…';

  @override
  String get hueSaturation => 'Matiz e saturação…';

  @override
  String get invertColors => 'Inverter cores';

  @override
  String get grayscale => 'Tons de cinza';

  @override
  String get brightness => 'Brilho';

  @override
  String get contrast => 'Contraste';

  @override
  String get hue => 'Matiz';

  @override
  String get saturation => 'Saturação';

  @override
  String get layersPanel => 'Camadas';

  @override
  String get colorPanel => 'Cor';

  @override
  String get swatchHint => 'Clique: primeiro plano. Clique direito: fundo.';

  @override
  String get opacity => 'Opacidade';

  @override
  String get blendMode => 'Modo de mesclagem';

  @override
  String get showLayer => 'Mostrar camada';

  @override
  String get hideLayer => 'Ocultar camada';

  @override
  String get hardness => 'Dureza';

  @override
  String get tolerance => 'Tolerância';

  @override
  String percent(int value) {
    return '$value%';
  }

  @override
  String get hiddenLayerHint => 'A camada ativa está oculta.';

  @override
  String get cancelCrop => 'Cancelar corte';

  @override
  String get applyCrop => 'Aplicar corte';

  @override
  String get textTitle => 'Texto';

  @override
  String get textHint => 'Digite o texto';

  @override
  String get fontSize => 'Tamanho';

  @override
  String get bold => 'Negrito';

  @override
  String get renameLayerTitle => 'Renomear camada';

  @override
  String get layerNameLabel => 'Nome';

  @override
  String get psdSimplified =>
      'Algumas coisas deste PSD (grupos, máscaras, efeitos ou texto editável) foram simplificadas. Salvar não mexe no original e pede um arquivo novo.';

  @override
  String get psdOpenedFlat =>
      'Este tipo de PSD abre como uma camada só. Salvar não mexe no original e pede um arquivo novo.';

  @override
  String exportedCopy(String format) {
    return 'Uma cópia achatada em $format foi salva. Salve como PSD para manter as camadas.';
  }

  @override
  String get blendNormal => 'Normal';

  @override
  String get blendDarken => 'Escurecer';

  @override
  String get blendMultiply => 'Multiplicação';

  @override
  String get blendColorBurn => 'Superexposição de cor';

  @override
  String get blendLighten => 'Clarear';

  @override
  String get blendScreen => 'Divisão';

  @override
  String get blendColorDodge => 'Subexposição de cor';

  @override
  String get blendLinearDodge => 'Subexposição linear (adicionar)';

  @override
  String get blendOverlay => 'Sobrepor';

  @override
  String get blendSoftLight => 'Luz suave';

  @override
  String get blendHardLight => 'Luz direta';

  @override
  String get blendDifference => 'Diferença';

  @override
  String get blendExclusion => 'Exclusão';

  @override
  String get blendHue => 'Matiz';

  @override
  String get blendSaturation => 'Saturação';

  @override
  String get blendColor => 'Cor';

  @override
  String get blendLuminosity => 'Luminosidade';
}
