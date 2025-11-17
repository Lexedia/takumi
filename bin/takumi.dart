import 'dart:io';

import 'package:takumi/src/models/options.dart';
import 'package:takumi/takumi.dart';

const primaryColour = 'hsla(354, 90%, 54%, 0.3)';
const primaryTextColour = 'hsl(354, 90%, 60%)';

void main(List<String> arguments) async {
  final renderer = Renderer();
  try {
    final frames = createAnimationNode().frames;
    final result = renderer.renderAnimationSync(
      frames,
      const RenderAnimationOptions(width: 1200, height: 630, format: .webp, shouldDrawDebugBorder: true),
    );
    print('Rendered output length: ${result.length}');

    File('output.webp').writeAsBytesSync(result);
  } finally {
    renderer.dispose();
  }
}

({Frames frames, int fps, int durationMs}) createAnimationNode() {
  const fps = 30;
  const durationMs = 1000;
  const totalFrames = (fps * durationMs) ~/ 1000;

  final frames = List<Frame>.generate(totalFrames, (index) {
    final node = createNode(index, totalFrames);
    final duration = Duration(milliseconds: durationMs * fps ~/ 1000);
    return (node, duration);
  });

  return (frames: frames, fps: fps, durationMs: durationMs);
}

Node createNode([int? i, int? totalFrames]) {
  final size = ((i != null && totalFrames != null)
      ? (i <= totalFrames / 2
          ? (i * 2)
          : (totalFrames - i) * 2)
      : 0);
  return ContainerNode(
    children: [
      ContainerNode(
        style:
            Style(
                display: .of(.flex),
                flexDirection: .of(.row),
                color: .of(.new(primaryTextColour)),
              )
              ..addCssProperty('gap', .of('16px'))
              ..addCssProperty('marginBottom', .of('12px'))
              ..addCssProperty('alignItems', .of('center')),
        children: [
          ImageNode(
            '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" viewBox="0 0 24 24" fill="none" stroke="$primaryTextColour" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-ban-icon lucide-ban"><path d="M4.929 4.929 19.07 19.071"/><circle cx="12" cy="12" r="10"/></svg>',
            style: Style(display: .of(.inline)),
          ),
          TextNode(
            'Takumi',
            style: Style(fontSize: .of(56), fontWeight: .of('600')),
          ),
        ],
      ),
      TextNode(
        'Hello, Takumi!',
        style:
            Style(fontSize: .of(84), fontWeight: .of('800'), lineClamp: .of(2))
              ..addCssProperty('textOverflow', .of('ellipsis'))
              ..addCssProperty('marginTop', .of('0.5em'))
              ..addCssProperty('marginBottom', .of('0.5em')),
      ),
      TextNode(
        'Hehe uwu.',
        style: Style(
          fontSize: .of(48),
          fontWeight: .of('500'),
          lineClamp: .of(2),
          color: .of(.new('rgba(240,240,240,0.8)')),
        )..addCssProperty('textOverflow', .of('ellipsis')),
      ),
    ],
    style: Style(
      display: .of(.flex),
      flexDirection: .of(.column),
      width: .of(.new(100, .percent)),
      height: .of(.new(100, .percent)),
      color: .of(.new('white')),
      backgroundColor: .of(.hex('#0c0c0c')),
      backgroundImage: .of(
        'linear-gradient(to top right, $primaryColour, transparent), noise-v1(opacity(0.2))',
      ),
    )..addCssProperty('padding', .of('4rem')),
  );
}
