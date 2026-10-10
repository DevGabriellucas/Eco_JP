/// Caminhos dos assets de assets/icons/. Use estas constantes em vez de
/// escrever o caminho na tela: renomear um arquivo vira mudança em um lugar só.
///
/// Cada subpasta precisa estar declarada no pubspec.yaml (o Flutter não
/// inclui subpastas sozinho).
abstract final class AppIcons {
  static const _dir = 'assets/icons/ui';

  static const arrowBack = '$_dir/arrow_back.svg';
  static const arrowLeft = '$_dir/arrow_left.svg';
  static const bell = '$_dir/bell.svg';
  static const camera = '$_dir/camera.svg';
  static const check = '$_dir/check.svg';
  static const clock = '$_dir/clock.svg';
  static const comment = '$_dir/comment.png';
  static const eyeClosed = '$_dir/eye_closed.svg';
  static const lamp = '$_dir/lamp.svg';
  static const message = '$_dir/message.svg';
  static const people = '$_dir/people.svg';
  static const safeShield = '$_dir/safe_shield.svg';
  static const send = '$_dir/send.svg';
  static const trash = '$_dir/trash.svg';

  static const todos = [
    arrowBack,
    arrowLeft,
    bell,
    camera,
    check,
    clock,
    comment,
    eyeClosed,
    lamp,
    message,
    people,
    safeShield,
    send,
    trash,
  ];
}

abstract final class AppIllustrations {
  static const _dir = 'assets/icons/illustrations';

  static const emailBranch = '$_dir/email_branch.svg';
  static const initialPageBranch = '$_dir/initial_page_branch.svg';
  static const splashBottom = '$_dir/splash_bottom.svg';
  static const stylePattern = '$_dir/style_pattern.svg';

  static const todos = [
    emailBranch,
    initialPageBranch,
    splashBottom,
    stylePattern,
  ];
}

abstract final class AppLogos {
  static const _dir = 'assets/icons/logos';

  static const ecohub = '$_dir/ecohub.svg';
  static const google = '$_dir/google.svg';

  static const todos = [ecohub, google];
}
