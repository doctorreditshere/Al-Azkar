import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:alazkar/src/core/constants/const.dart';
import 'package:alazkar/src/core/extension/extension_platform.dart';
import 'package:alazkar/src/core/models/zikr.dart';
import 'package:alazkar/src/core/models/zikr_title.dart';
import 'package:alazkar/src/core/utils/app_print.dart';
import 'package:alazkar/src/features/share_as_image/data/repository/share_image_repo.dart';
import 'package:alazkar/src/features/share_as_image/presentation/components/image_builder.dart';
import 'package:alazkar/src/features/zikr_content_viewer/presentation/components/zikr_content_builder.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

part 'share_as_image_event.dart';
part 'share_as_image_state.dart';

class ShareAsImageBloc extends Bloc<ShareAsImageEvent, ShareAsImageState> {
  final ShareAsImageRepo shareAsImageRepo;
  ShareAsImageBloc(this.shareAsImageRepo) : super(ShareAsImageLoadingState()) {
    on<ShareAsImageStartEvent>(_start);
    on<ShareAsImageShareEvent>(_share);
    on<ShareAsImageChangeFontSizeEvent>(_fontSizeChange);
    on<ShareAsImageIncreaseFontSizeEvent>(_increaseFontSize);
    on<ShareAsImageDecreaseFontSizeEvent>(_decreaseFontSize);
    on<ShareAsImageResetFontSizeEvent>(_resetFontSize);
    on<ShareAsImageDoubleTapEvent>(_doubleTap);
    on<ShareAsImageChangeWidthEvent>(_changeWidth);
    on<ShareAsImageChangeBackgroundColorEvent>(_changeBackgroundColor);
    on<ShareAsImageChangeTextColorEvent>(_changeTextColor);
    on<ShareAsImageChangeShowAppInfoEvent>(_changeShowAppInfo);
  }

  FutureOr<void> _start(
    ShareAsImageStartEvent event,
    Emitter<ShareAsImageState> emit,
  ) {
    emit(
      ShareAsImageLoadedState(
        zikrTitle: event.zikrTitle,
        zikr: event.zikr,
        isLoading: false,
        showAppInfo: shareAsImageRepo.showAppInfo,
        textColor: shareAsImageRepo.textColor,
        backgroundColor: shareAsImageRepo.backgroundColor,
        fontSize: shareAsImageRepo.fontSize,
        width: shareAsImageRepo.imageWidth,
        transformationController: TransformationController(),
      ),
    );
  }

  FutureOr<void> _share(
    ShareAsImageShareEvent event,
    Emitter<ShareAsImageState> emit,
  ) async {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }

    emit(state.copyWith(isLoading: true));
    try {
      final RenderRepaintBoundary boundary = (event.key.currentContext!
          .findRenderObject() as RenderRepaintBoundary?)!;

      const double pixelRatio = 3;
      final image = await boundary.toImage(pixelRatio: pixelRatio);

      final byteData = await image.toByteData(format: ImageByteFormat.png);

      if (PlatformExtension.isDesktop) {
        await _saveDesktop(byteData);
      } else {
        await _savePhone(byteData);
      }
    } catch (e) {
      appPrint(e.toString());
    }
    emit(state.copyWith(isLoading: false));
  }

  Future _saveDesktop(ByteData? byteData) async {
    if (byteData == null) return;

    final Uint8List uint8List = byteData.buffer.asUint8List();

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'SharedImage-$timestamp.png',
    );

    if (outputFile == null) return;
    if (!outputFile.endsWith(".png")) {
      outputFile += ".png";
    }

    appPrint(outputFile);

    final File file = File(outputFile);
    await file.writeAsBytes(uint8List);
  }

  Future _savePhone(ByteData? byteData) async {
    final tempDir = await getTemporaryDirectory();

    final File file = await File('${tempDir.path}/SharedImage.png').create();
    await file.writeAsBytes(byteData!.buffer.asUint8List());

    await Share.shareXFiles([XFile(file.path)]);

    await file.delete();
  }

  /// Font size
  FutureOr<void> _fontSizeChange(
    ShareAsImageChangeFontSizeEvent event,
    Emitter<ShareAsImageState> emit,
  ) async {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }

    final double newFontSize = event.fontSize.clamp(5, 50);
    emit(state.copyWith(fontSize: newFontSize));
    await shareAsImageRepo.updateFontSize(newFontSize);
  }

  FutureOr<void> _increaseFontSize(
    ShareAsImageIncreaseFontSizeEvent event,
    Emitter<ShareAsImageState> emit,
  ) {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }

    add(ShareAsImageChangeFontSizeEvent(fontSize: state.fontSize + 1));
  }

  FutureOr<void> _decreaseFontSize(
    ShareAsImageDecreaseFontSizeEvent event,
    Emitter<ShareAsImageState> emit,
  ) {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }

    add(ShareAsImageChangeFontSizeEvent(fontSize: state.fontSize - 1));
  }

  FutureOr<void> _resetFontSize(
    ShareAsImageResetFontSizeEvent event,
    Emitter<ShareAsImageState> emit,
  ) {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }
    add(const ShareAsImageChangeFontSizeEvent(fontSize: 25));
  }

  ///
  FutureOr<void> _doubleTap(
    ShareAsImageDoubleTapEvent event,
    Emitter<ShareAsImageState> emit,
  ) {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }

    final TransformationController newValue = state.transformationController;
    newValue.value = fitImageToScreen(event.imageSize, event.screenSize);
    emit(state.copyWith(transformationController: newValue));
  }

  Matrix4 fitImageToScreen(Size imageSize, Size screenSize) {
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final childWidth = imageSize.width;
    final childHeight = imageSize.height;

    final scaleX = screenWidth / childWidth;
    final scaleY = screenHeight / childHeight;

    final scale = min(scaleX, scaleY);

    return Matrix4.diagonal3Values(
          scale,
          scale,
          1,
        ) *
        Matrix4.translationValues(
          (screenWidth - childWidth * scale) / 2,
          (screenHeight - childHeight * scale) / 2,
          0,
        ) as Matrix4;
  }

  ///
  FutureOr<void> _changeWidth(
    ShareAsImageChangeWidthEvent event,
    Emitter<ShareAsImageState> emit,
  ) async {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }
    final double newWidth = event.width.clamp(600, double.infinity);
    emit(state.copyWith(width: newWidth));
    await shareAsImageRepo.updateImageWidth(newWidth);
  }

  FutureOr<void> _changeBackgroundColor(
    ShareAsImageChangeBackgroundColorEvent event,
    Emitter<ShareAsImageState> emit,
  ) async {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }
    final Color newColor = event.backgroundColor;
    emit(state.copyWith(backgroundColor: newColor));
    await shareAsImageRepo.updateBackgroundColor(newColor);
  }

  FutureOr<void> _changeTextColor(
    ShareAsImageChangeTextColorEvent event,
    Emitter<ShareAsImageState> emit,
  ) async {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }
    final Color newColor = event.textColor;
    emit(state.copyWith(textColor: newColor));
    await shareAsImageRepo.updateTextColor(newColor);
  }

  FutureOr<void> _changeShowAppInfo(
    ShareAsImageChangeShowAppInfoEvent event,
    Emitter<ShareAsImageState> emit,
  ) async {
    final state = this.state;
    if (state is! ShareAsImageLoadedState) {
      return null;
    }
    final bool newValue = event.showAppInfo;
    emit(state.copyWith(showAppInfo: newValue));
    await shareAsImageRepo.updateShowAppInfo(newValue);
  }
}
