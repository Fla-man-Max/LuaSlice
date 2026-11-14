package funkin.provider;

import android.content.res.AssetFileDescriptor;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.graphics.Point;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract.Document;
import android.provider.DocumentsContract.Root;
import android.provider.DocumentsProvider;
import android.webkit.MimeTypeMap;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.LinkedList;

/**
 * @see https://github.com/termux/termux-app/blob/7bceab88e2272f961d1b94ef736f1a9e20173247/app/src/main/java/com/termux/filepicker/TermuxDocumentsProvider.java
 */
public class DataFolderProvider extends DocumentsProvider
{
  private DataFolderPaths paths;

  private static final String[] DEFAULT_ROOT_PROJECTION = new String[] {
    Root.COLUMN_ROOT_ID,
    Root.COLUMN_MIME_TYPES,
    Root.COLUMN_FLAGS,
    Root.COLUMN_ICON,
    Root.COLUMN_TITLE,
    Root.COLUMN_SUMMARY,
    Root.COLUMN_DOCUMENT_ID,
    Root.COLUMN_AVAILABLE_BYTES
  };

  private static final String[] DEFAULT_DOCUMENT_PROJECTION = new String[] {
    Document.COLUMN_DOCUMENT_ID,
    Document.COLUMN_MIME_TYPE,
    Document.COLUMN_DISPLAY_NAME,
    Document.COLUMN_LAST_MODIFIED,
    Document.COLUMN_FLAGS,
    Document.COLUMN_SIZE
  };

  @Override
  public Cursor queryRoots(String[] projection)
  {
    final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_ROOT_PROJECTION);

    if (paths == null)
      return result;

    final File root = paths.root();
    final MatrixCursor.RowBuilder row = result.newRow();

    row.add(Root.COLUMN_ROOT_ID, getDocIdForFile(root));
    row.add(Root.COLUMN_DOCUMENT_ID, getDocIdForFile(root));
    row.add(Root.COLUMN_SUMMARY, "Data Folder");
    row.add(Root.COLUMN_FLAGS, Root.FLAG_SUPPORTS_CREATE | Root.FLAG_SUPPORTS_SEARCH | Root.FLAG_SUPPORTS_IS_CHILD);
    row.add(Root.COLUMN_TITLE, "::APP_TITLE::");
    row.add(Root.COLUMN_MIME_TYPES, "*/*");
    row.add(Root.COLUMN_AVAILABLE_BYTES, root.getFreeSpace());
    ::if (APP_PACKAGE != "")::
    row.add(Root.COLUMN_ICON, ::APP_PACKAGE::.R.drawable.icon);
    ::end::

    return result;
  }

  @Override
  public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException
  {
    final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
    includeFile(result, documentId, null);
    return result;
  }

  @Override
  public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder) throws FileNotFoundException
  {
    final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);

    File parent = getFileForDocId(parentDocumentId);

    for (File file : paths.children(parent))
      includeFile(result, null, file);

    return result;
  }

  @Override
  public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal) throws FileNotFoundException
  {
    return ParcelFileDescriptor.open(getFileForDocId(documentId), ParcelFileDescriptor.parseMode(mode));
  }

  @Override
  public AssetFileDescriptor openDocumentThumbnail(String documentId, Point sizeHint, CancellationSignal signal) throws FileNotFoundException
  {
    final File file = getFileForDocId(documentId);
    final ParcelFileDescriptor pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    return new AssetFileDescriptor(pfd, 0, file.length());
  }

  @Override
  public boolean onCreate()
  {
    File root = getContext().getExternalFilesDir(null);
    if (root == null)
      return false;

    try
    {
      paths = new DataFolderPaths(root);
    }
    catch (IOException e)
    {
      return false;
    }

    return true;
  }

  @Override
  public String createDocument(String parentDocumentId, String mimeType, String displayName) throws FileNotFoundException
  {
    File parentFile = getFileForDocId(parentDocumentId);

    File newFile = paths.child(parentFile, displayName);

    int noConflictId = 2;

    while (newFile.exists())
    {
      newFile = paths.child(parentFile, displayName + " (" + noConflictId++ + ")");
    }

    try
    {
      boolean succeeded;

      if (Document.MIME_TYPE_DIR.equals(mimeType))
        succeeded = newFile.mkdir();
      else
        succeeded = newFile.createNewFile();

      if (!succeeded)
        throw new FileNotFoundException("Failed to create document with id " + newFile.getPath());
    }
    catch (IOException e)
    {
      throw new FileNotFoundException("Failed to create document with id " + newFile.getPath());
    }

    return getDocIdForFile(newFile);
  }

  @Override
  public void deleteDocument(String documentId) throws FileNotFoundException
  {
    File file = getFileForDocId(documentId);
    if (file.equals(paths.root())) throw new FileNotFoundException("Cannot delete the data folder root");
    if (!deleteRecursive(file))
      throw new FileNotFoundException("Failed to delete document with id " + documentId);
  }

  @Override
  public String getDocumentType(String documentId) throws FileNotFoundException
  {
    return getMimeType(getFileForDocId(documentId));
  }

  @Override
  public Cursor querySearchDocuments(String rootId, String query, String[] projection) throws FileNotFoundException
  {
    final MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);

    final LinkedList<File> pending = new LinkedList<>();

    pending.add(getFileForDocId(rootId));

    final int MAX_SEARCH_RESULTS = 50;

    while (!pending.isEmpty() && result.getCount() < MAX_SEARCH_RESULTS)
    {
      final File file = pending.removeFirst();

      if (file.isDirectory())
        pending.addAll(paths.children(file));
      else if (file.getName().toLowerCase().contains(query))
        includeFile(result, null, file);
    }

    return result;
  }

  @Override
  public boolean isChildDocument(String parentDocumentId, String documentId)
  {
    try
    {
      File parent = getFileForDocId(parentDocumentId);
      File child = getFileForDocId(documentId);
      return DataFolderPaths.isDescendant(parent, child);
    }
    catch (IOException e)
    {
      return false;
    }
  }

  private boolean deleteRecursive(File file) throws FileNotFoundException
  {
    if (file.isDirectory())
    {
      File[] children = file.listFiles();

      if (children != null)
      {
        for (File child : children)
        {
          if (!deleteRecursive(paths.child(file, child.getName())))
            return false;
        }
      }
    }

    return file.delete();
  }

  private static String getDocIdForFile(File file)
  {
    return file.getAbsolutePath();
  }

  private File getFileForDocId(String docId) throws FileNotFoundException
  {
    if (paths == null)
      throw new FileNotFoundException("Base directory not available");
    return paths.resolve(docId);
  }

  private static String getMimeType(File file)
  {
    if (file == null || file.isDirectory())
      return Document.MIME_TYPE_DIR;

    String name = file.getName();

    int lastDot = name.lastIndexOf('.');

    if (lastDot >= 0)
    {
      String extension = name.substring(lastDot + 1).toLowerCase();

      String mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension);

      if (mime != null)
        return mime;
    }

    return "application/octet-stream";
  }

  private void includeFile(MatrixCursor result, String docId, File file) throws FileNotFoundException
  {
    if (docId == null)
      docId = getDocIdForFile(file);
    else
      file = getFileForDocId(docId);

    int flags = 0;

    if (file.isDirectory())
    {
      if (file.canWrite())
        flags |= Document.FLAG_DIR_SUPPORTS_CREATE;
    }
    else if (file.canWrite())
    {
      flags |= Document.FLAG_SUPPORTS_WRITE;
    }

    if (!file.equals(paths.root()) && file.getParentFile() != null && file.getParentFile().canWrite())
      flags |= Document.FLAG_SUPPORTS_DELETE;

    final String mimeType = getMimeType(file);

    if (mimeType.startsWith("image/"))
      flags |= Document.FLAG_SUPPORTS_THUMBNAIL;

    final MatrixCursor.RowBuilder row = result.newRow();
    row.add(Document.COLUMN_DOCUMENT_ID, docId);
    row.add(Document.COLUMN_DISPLAY_NAME, file.getName());
    row.add(Document.COLUMN_SIZE, file.length());
    row.add(Document.COLUMN_MIME_TYPE, mimeType);
    row.add(Document.COLUMN_LAST_MODIFIED, file.lastModified());
    row.add(Document.COLUMN_FLAGS, flags);
    ::if (APP_PACKAGE != "")::
    row.add(Document.COLUMN_ICON, ::APP_PACKAGE::.R.drawable.icon);
    ::end::
  }
}
