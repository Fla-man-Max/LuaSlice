package funkin.provider;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

final class DataFolderPaths
{
  private final File root;

  DataFolderPaths(File root) throws IOException
  {
    this.root = root.getCanonicalFile();
    if (!this.root.isDirectory()) throw new FileNotFoundException("Data folder is not available");
  }

  File root()
  {
    return root;
  }

  File resolve(String docId) throws FileNotFoundException
  {
    final File file = contained((docId == null || docId.isEmpty()) ? root : new File(docId));
    if (!file.exists())
      throw new FileNotFoundException(file.getAbsolutePath() + " not found");
    return file;
  }

  File child(File parent, String name) throws FileNotFoundException
  {
    final File directory = contained(parent);
    if (!directory.isDirectory()) throw new FileNotFoundException("Parent is not a directory");
    if (name == null || name.isEmpty() || name.equals(".") || name.equals("..")
        || name.indexOf('/') >= 0 || name.indexOf('\\') >= 0 || name.indexOf('\0') >= 0)
      throw new FileNotFoundException("Invalid document name");
    return directChild(new File(directory, name));
  }

  List<File> children(File parent) throws FileNotFoundException
  {
    File[] entries;
    final File directory = contained(parent);
    try
    {
      entries = directory.listFiles();
    }
    catch (SecurityException denied)
    {
      return Collections.emptyList();
    }
    if (entries == null) return Collections.emptyList();

    final List<File> result = new ArrayList<>(entries.length);
    for (File entry : entries)
    {
      try
      {
        result.add(directChild(entry));
      }
      catch (FileNotFoundException unavailable)
      {
        continue;
      }
    }
    return result;
  }

  static boolean isDescendant(File parent, File child)
  {
    for (File directory = child.getParentFile(); directory != null; directory = directory.getParentFile())
    {
      if (parent.equals(directory)) return true;
    }
    return false;
  }

  private File directChild(File entry) throws FileNotFoundException
  {
    final File resolved = contained(entry);
    if (!entry.equals(resolved)) throw new FileNotFoundException("Document is a path alias");
    return resolved;
  }

  private File contained(File file) throws FileNotFoundException
  {
    if (!file.isAbsolute()) throw new FileNotFoundException("Document ID must be absolute");
    final File resolved;
    try
    {
      resolved = file.getCanonicalFile();
    }
    catch (IOException | SecurityException error)
    {
      FileNotFoundException failure = new FileNotFoundException("Could not resolve document path");
      failure.initCause(error);
      throw failure;
    }
    if (!root.equals(resolved) && !isDescendant(root, resolved))
      throw new FileNotFoundException("Document is outside the data folder");
    return resolved;
  }
}
