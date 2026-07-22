package funkin.util;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
import android.provider.OpenableColumns;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import org.haxe.extension.Extension;

public class MobileFileUtil
{
  private static final int FILE_DIALOG_REQUEST_START = 0x4C00;
  private static final int FILE_DIALOG_REQUEST_END = 0x4CFF;
  private static int nextFileDialogRequest = FILE_DIALOG_REQUEST_START;

  public static int openFileDialog(String title)
  {
    if (Extension.mainActivity == null)
      return -1;

    final int requestCode = nextRequestCode();
    new Handler(Looper.getMainLooper()).post(() ->
    {
      try
      {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        setInitialChartsDirectory(intent);
        Extension.mainActivity.startActivityForResult(intent, requestCode);
      }
      catch (Exception exception)
      {
        funkin.extensions.CallbackUtil.callMethod("onFileDialogResult", requestCode, Activity.RESULT_CANCELED, "");
      }
    });
    return requestCode;
  }

  public static int saveFileDialog(String title, String defaultFileName)
  {
    if (Extension.mainActivity == null)
      return -1;

    final int requestCode = nextRequestCode();
    new Handler(Looper.getMainLooper()).post(() ->
    {
      try
      {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("application/octet-stream");
        if (defaultFileName != null && !defaultFileName.isEmpty())
          intent.putExtra(Intent.EXTRA_TITLE, defaultFileName);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        Extension.mainActivity.startActivityForResult(intent, requestCode);
      }
      catch (Exception exception)
      {
        funkin.extensions.CallbackUtil.callMethod("onFileDialogResult", requestCode, Activity.RESULT_CANCELED, "");
      }
    });
    return requestCode;
  }

  public static boolean isFileDialogRequest(int requestCode)
  {
    return requestCode >= FILE_DIALOG_REQUEST_START && requestCode <= FILE_DIALOG_REQUEST_END;
  }

  private static synchronized int nextRequestCode()
  {
    int requestCode = nextFileDialogRequest++;
    if (nextFileDialogRequest > FILE_DIALOG_REQUEST_END)
      nextFileDialogRequest = FILE_DIALOG_REQUEST_START;
    return requestCode;
  }

  private static void setInitialChartsDirectory(Intent intent)
  {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O)
      return;

    try
    {
      File chartsDirectory = new File(Extension.mainActivity.getExternalFilesDir(null), "Charts");
      if (!chartsDirectory.exists())
        chartsDirectory.mkdirs();

      Uri initialUri = DocumentsContract.buildDocumentUri(
        Extension.mainActivity.getPackageName() + ".docprovider",
        chartsDirectory.getAbsolutePath());
      intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri);
    }
    catch (Exception exception)
    {
    }
  }

  public static String copyUriToCache(String uriText)
  {
    if (Extension.mainActivity == null || uriText == null)
      return null;

    Uri uri = Uri.parse(uriText);
    File directory = new File(Extension.mainActivity.getCacheDir(), "luaslice-picker");
    if (!directory.exists() && !directory.mkdirs())
      return null;

    String name = getDisplayName(uriText).replaceAll("[\\/:*?\"<>|]", "_");
    File destination = new File(directory, System.nanoTime() + "-" + name);

    try (InputStream input = Extension.mainActivity.getContentResolver().openInputStream(uri);
         OutputStream output = new FileOutputStream(destination))
    {
      if (input == null)
        return null;
      copy(input, output);
      return destination.getAbsolutePath();
    }
    catch (Exception exception)
    {
      return null;
    }
  }

  public static boolean copyFileToUri(String sourcePath, String uriText)
  {
    if (Extension.mainActivity == null || sourcePath == null || uriText == null)
      return false;

    try (InputStream input = new FileInputStream(sourcePath);
         OutputStream output = Extension.mainActivity.getContentResolver().openOutputStream(Uri.parse(uriText), "wt"))
    {
      if (output == null)
        return false;
      copy(input, output);
      return true;
    }
    catch (Exception exception)
    {
      return false;
    }
  }

  public static String getDisplayName(String uriText)
  {
    if (Extension.mainActivity == null || uriText == null)
      return "selected-file";

    Uri uri = Uri.parse(uriText);
    try (Cursor cursor = Extension.mainActivity.getContentResolver().query(uri, null, null, null, null))
    {
      if (cursor != null && cursor.moveToFirst())
      {
        int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
        if (index >= 0)
          return cursor.getString(index);
      }
    }
    catch (Exception exception)
    {
    }

    String segment = uri.getLastPathSegment();
    return segment == null || segment.length() == 0 ? "selected-file" : segment;
  }

  private static void copy(InputStream input, OutputStream output) throws Exception
  {
    byte[] buffer = new byte[65536];
    int count;
    while ((count = input.read(buffer)) >= 0)
      output.write(buffer, 0, count);
    output.flush();
  }
}
