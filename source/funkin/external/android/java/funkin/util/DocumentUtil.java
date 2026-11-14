package funkin.util;

import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import org.haxe.extension.Extension;

public class DocumentUtil
{
  public static String getDisplayName(String path)
  {
    if (Extension.mainContext == null || path == null || !path.startsWith("content://")) return null;

    try (Cursor cursor = Extension.mainContext.getContentResolver().query(
      Uri.parse(path), new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null))
    {
      return cursor != null && cursor.moveToFirst() ? cursor.getString(0) : null;
    }
    catch (RuntimeException error)
    {
      return null;
    }
  }
}
