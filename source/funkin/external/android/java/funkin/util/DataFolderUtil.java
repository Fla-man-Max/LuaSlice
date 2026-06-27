package funkin.util;

import android.content.Intent;
import android.content.ActivityNotFoundException;
import android.net.Uri;
import android.os.Build;
import android.provider.DocumentsContract;
import java.io.File;
import java.io.IOException;

import org.haxe.extension.Extension;

public class DataFolderUtil
{
  /**
   * A method that opens the Application's data folder for browsing through the Storage Access Framework.
   * It's highly based on some code borrowed from Mterial Files
   * https://github.com/zhanghai/MaterialFiles
   */
  public static void openDataFolder(int requestCode)
  {
    ::if (APP_PACKAGE != "")::
    if (Extension.mainActivity != null)
    {
      File dataFolder = Extension.mainActivity.getExternalFilesDir(null);
      if (dataFolder == null)
        return;

      String documentId;
      try
      {
        documentId = dataFolder.getCanonicalPath();
      }
      catch (IOException exception)
      {
        documentId = dataFolder.getAbsolutePath();
      }

      Uri dataUri = DocumentsContract.buildDocumentUri("::APP_PACKAGE::.docprovider", documentId);
      Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
        intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, dataUri);

      intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
      intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
      intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
      intent.addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);

      try
      {
        Extension.mainActivity.startActivityForResult(intent, requestCode);
      }
      catch (ActivityNotFoundException exception)
      {
        Intent fallback = new Intent(Intent.ACTION_VIEW);
        fallback.setDataAndType(dataUri, DocumentsContract.Document.MIME_TYPE_DIR);
        fallback.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        fallback.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        Extension.mainActivity.startActivityForResult(fallback, requestCode);
      }
    }
    ::end::
  }
}
