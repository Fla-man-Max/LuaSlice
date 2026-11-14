package funkin.provider;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

public final class DataFolderPathsTest
{
  private static int checks;

  public static void main(String[] args) throws Exception
  {
    Path fixture = Files.createTempDirectory("luaslice-provider-");
    fixture.toFile().deleteOnExit();
    File root = directory(fixture.resolve("data"));
    File nested = directory(root.toPath().resolve("mods"));
    File chart = file(nested.toPath().resolve("chart.json"));
    File sibling = directory(fixture.resolve("data-other"));
    File outside = file(sibling.toPath().resolve("outside.txt"));
    DataFolderPaths paths = new DataFolderPaths(root);

    check(paths.resolve(null).equals(root.getCanonicalFile()), "null ID opens the data root");
    check(paths.resolve("").equals(root.getCanonicalFile()), "empty ID opens the data root");
    check(paths.resolve(chart.getAbsolutePath()).equals(chart.getCanonicalFile()), "nested document opens");
    rejects(() -> paths.resolve(outside.getAbsolutePath()), "an existing sibling with a similar prefix is outside the data folder");
    String parentPath = new File(root, "../data-other/outside.txt").getPath();
    rejects(() -> paths.resolve(parentPath), "a parent-relative component cannot leave the data folder");
    rejects(() -> paths.resolve("chart.json"), "relative document IDs are not resolved against the working directory");
    rejects(() -> paths.resolve(new File(root, "missing.txt").getPath()), "a missing document fails cleanly");

    File rootCanonical = root.getCanonicalFile();
    File nestedCanonical = nested.getCanonicalFile();
    check(paths.children(root).size() == 1 && paths.children(root).contains(nestedCanonical), "root listing returns its own directory");
    check(paths.children(nested).contains(chart.getCanonicalFile()), "nested listing returns the chart");
    rejects(() -> { paths.children(sibling); return null; }, "listing cannot start outside the data folder");
    check(DataFolderPaths.isDescendant(rootCanonical, chart.getCanonicalFile()), "nested documents count as descendants");
    check(!DataFolderPaths.isDescendant(rootCanonical, rootCanonical), "the root is not its own child");
    check(!DataFolderPaths.isDescendant(rootCanonical, outside.getCanonicalFile()), "a similar folder prefix is not a child");

    File candidate = paths.child(nested, "New Chart.json");
    check(candidate.getParentFile().equals(nestedCanonical) && !candidate.exists(), "creation resolves a new name without touching storage");
    check(paths.child(nested, "chart.json (2)").getName().equals("chart.json (2)"), "duplicate suffixes remain valid names");
    rejects(() -> paths.child(sibling, "new.txt"), "creation cannot use an outside parent");
    rejects(() -> paths.child(chart, "new.txt"), "creation requires a directory");
    for (String name : new String[] {null, "", ".", "..", "nested/file", "nested\\file", "bad\0name"})
      rejects(() -> paths.child(nested, name), "creation rejects a non-leaf display name");

    Path link = nested.toPath().resolve("outside-link");
    boolean linked = false;
    try
    {
      Files.createSymbolicLink(link, outside.toPath());
      link.toFile().deleteOnExit();
      linked = true;
    }
    catch (IOException | UnsupportedOperationException | SecurityException unavailable)
    {
      System.out.println("SKIPPED: symbolic-link fixture unavailable on this machine");
    }
    if (linked)
    {
      rejects(() -> paths.resolve(link.toString()), "a link cannot resolve to an outside file");
      rejects(() -> paths.child(nested, "outside-link"), "creation cannot reuse a link outside the data folder");
      check(!paths.children(nested).contains(link.toFile()), "listing does not expose an outside link");
    }
    System.out.println("DATA_FOLDER_PATHS_OK: " + checks + " checks");
  }

  private static File directory(Path path) throws Exception
  {
    File result = Files.createDirectory(path).toFile();
    result.deleteOnExit();
    return result;
  }

  private static File file(Path path) throws Exception
  {
    File result = Files.createFile(path).toFile();
    result.deleteOnExit();
    return result;
  }

  private static void check(boolean condition, String label)
  {
    if (!condition) throw new AssertionError(label);
    checks++;
  }

  private static void rejects(DocumentLookup lookup, String label) throws Exception
  {
    try
    {
      lookup.get();
    }
    catch (FileNotFoundException expected)
    {
      checks++;
      return;
    }
    throw new AssertionError(label);
  }

  @FunctionalInterface
  private interface DocumentLookup
  {
    File get() throws Exception;
  }
}
