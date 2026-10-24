import 'package:image_picker/image_picker.dart';

final ImagePicker _imagePicker = ImagePicker();

Future<XFile?> pickProductImage() {
  return _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
}
