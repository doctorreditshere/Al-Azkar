import 'package:alazkar/src/features/zikr_source_filter/data/models/zikr_filter.dart';
import 'package:alazkar/src/features/zikr_source_filter/data/models/zikr_filter_enum.dart';
import 'package:alazkar/src/features/zikr_source_filter/data/repository/zikr_filter_storage.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'zikr_source_filter_state.dart';

class ZikrSourceFilterCubit extends Cubit<ZikrSourceFilterState> {
  ZikrSourceFilterCubit()
      : super(
          const ZikrSourceFilterState(
            filters: [],
          ),
        );

  void start() {
    final List<Filter> filters = ZikrFilter.values
        .map(
          (e) => Filter(
            filter: e,
            isActivated: ZikrFilterStorage.getFilterStatus(e),
          ),
        )
        .toList();

    emit(ZikrSourceFilterState(filters: filters));
  }

  Future toggleFilter(Filter filter) async {
    final newFilter = filter.copyWith(isActivated: !filter.isActivated);
    await ZikrFilterStorage.setFilterStatus(newFilter);

    final newList = List.of(state.filters).map((e) {
      if (e.filter == newFilter.filter) return newFilter;
      return e;
    }).toList();

    emit(state.copyWith(filters: newList));
  }
}
