package funkin.util;

import android.os.Build;
import android.view.Display;
import android.view.WindowManager;
import org.haxe.extension.Extension;

public class DisplayUtil
{
  public static float getMaximumRefreshRate()
  {
    if (Extension.mainActivity == null)
      return 0.0f;

    Display display = Extension.mainActivity.getWindowManager().getDefaultDisplay();
    if (display == null)
      return 0.0f;

    float maximumRefreshRate = display.getRefreshRate();
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
    {
      Display.Mode currentMode = display.getMode();
      for (Display.Mode mode : display.getSupportedModes())
      {
        boolean sameSize = mode.getPhysicalWidth() == currentMode.getPhysicalWidth()
          && mode.getPhysicalHeight() == currentMode.getPhysicalHeight();
        if (sameSize)
          maximumRefreshRate = Math.max(maximumRefreshRate, mode.getRefreshRate());
      }
    }

    return maximumRefreshRate;
  }

  public static void setHighRefreshRateEnabled(final boolean enabled)
  {
    if (Extension.mainActivity == null)
      return;

    Extension.mainActivity.runOnUiThread(new Runnable()
    {
      @Override
      public void run()
      {
        Display display = Extension.mainActivity.getWindowManager().getDefaultDisplay();
        if (display == null)
          return;

        WindowManager.LayoutParams attributes = Extension.mainActivity.getWindow().getAttributes();
        attributes.preferredRefreshRate = enabled ? getMaximumRefreshRate() : 0.0f;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
        {
          int bestModeId = 0;
          if (enabled)
          {
            Display.Mode currentMode = display.getMode();
            float bestRefreshRate = currentMode.getRefreshRate();
            bestModeId = currentMode.getModeId();

            for (Display.Mode mode : display.getSupportedModes())
            {
              boolean sameSize = mode.getPhysicalWidth() == currentMode.getPhysicalWidth()
                && mode.getPhysicalHeight() == currentMode.getPhysicalHeight();
              if (sameSize && mode.getRefreshRate() > bestRefreshRate)
              {
                bestRefreshRate = mode.getRefreshRate();
                bestModeId = mode.getModeId();
              }
            }
          }
          attributes.preferredDisplayModeId = bestModeId;
        }

        Extension.mainActivity.getWindow().setAttributes(attributes);
      }
    });
  }
}
