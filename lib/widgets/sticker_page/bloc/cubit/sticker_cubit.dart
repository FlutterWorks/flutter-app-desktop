import 'package:flutter_app/bloc/stream_cubit.dart';
import 'package:flutter_app/db/mixin_database.dart';

class StickerCubit extends StreamCubit<List<Sticker>> {
  StickerCubit(Stream<List<Sticker>> stream) : super([], stream);
}
