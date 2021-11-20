/*
 * Xournal++
 *
 * Part of the customizable toolbars
 *
 * @author Xournal++ Team
 * https://github.com/xournalpp/xournalpp
 *
 * @license GNU GPLv2 or later
 */

#pragma once

#include <string>
#include <vector>

#include "control/zoom/ZoomListener.h"
#include "util/IconNameHelper.h"

#include "AbstractToolItem.h"


#define SCALE_LOG_OFFSET 0.20753

class ZoomControl;

class ToolZoomSlider: public AbstractToolItem, public ZoomListener {
public:
    ToolZoomSlider(ActionHandler* handler, std::string id, ActionType type, ZoomControl* zoom,
                   IconNameHelper iconNameHelper);
    virtual ~ToolZoomSlider();

public:
    static void sliderChanged(GtkRange* range, ToolZoomSlider* self);
    static bool sliderButtonPress(GtkRange* range, GdkEvent* event, ToolZoomSlider* self);
    static bool sliderButtonRelease(GtkRange* range, GdkEvent* event, ToolZoomSlider* self);
    static bool sliderHoverScroll(GtkWidget* range, /* GdkEventScroll */ GdkEvent* event, ToolZoomSlider* self);
    static gchar* sliderFormatValue(GtkRange* range, gdouble value, ToolZoomSlider* self);

    void zoomChanged() override;
    void zoomRangeValuesChanged() override;
    std::string getToolDisplayName() override;

    // Should be called when the window size changes
    void updateScaleMarks();
    GtkWidget* createItem(bool horizontal) override;
    GtkWidget* createTmpItem(bool horizontal) override;

protected:
    void enable(bool enabled) override;
    GtkWidget* newItem() override;
    GtkWidget* getNewToolIcon() override;

private:
    static double scaleFunc(double x);
    static double scaleFuncInv(double x);

private:
    /**
     * The slider is currently changing by user, do not update value
     */
    bool sliderChangingByZoomControlOrInit = false;
    bool sliderChangingBySliderDrag = false;
    bool sliderChangingBySliderHoverScroll = false;
    gint64 sliderHoverScrollLastTime = 0;

    GtkWidget* slider = nullptr;
    ZoomControl* zoom = nullptr;
    bool horizontal = true;
    IconNameHelper iconNameHelper;
};
