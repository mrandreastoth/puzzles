//
//  GameView.m
//  Puzzles
//
//  Created by Greg Hewgill on 7/03/13.
//  Copyright (c) 2013 Greg Hewgill. All rights reserved.
//

#import "GameView.h"

#include "puzzles.h"

typedef float rgb[3];

struct frontend {
    void *gv;
    rgb *colours;
    int ncolours;
    BOOL clipping;
};

extern const struct drawing_api ios_drawing;

const int ButtonDown[3] = {LEFT_BUTTON,  RIGHT_BUTTON,  MIDDLE_BUTTON};
const int ButtonDrag[3] = {LEFT_DRAG,    RIGHT_DRAG,    MIDDLE_DRAG};
const int ButtonUp[3]   = {LEFT_RELEASE, RIGHT_RELEASE, MIDDLE_RELEASE};

const int NBUTTONS = 10;

@implementation GameView {
    const game *ourgame;
    midend *me;
    frontend fe;
    CGRect usable_frame;
    NSTimer *timer;
    UIButton *buttons[NBUTTONS];
    int touchState;
    int touchX, touchY;
    int touchButton;
    NSTimer *touchTimer;
}

@synthesize bitmap;
@synthesize statusbar;

- (id)initWithFrame:(CGRect)frame game:(const game *)g
{
    self = [super initWithFrame:frame];
    if (self) {
        ourgame = g;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        fe.gv = (__bridge void *)(self);
        {
            char buf[80], value[10];
            int j, k;
    
            sprintf(buf, "%s_TILESIZE", ourgame->name);
            for (j = k = 0; buf[j]; j++)
                if (!isspace((unsigned char)buf[j]))
                    buf[k++] = toupper((unsigned char)buf[j]);
            buf[k] = '\0';
            snprintf(value, sizeof(value), "%d", ourgame->preferred_tilesize*4);
            setenv(buf, value, 1);
        }
        me = midend_new(&fe, ourgame, &ios_drawing, &fe);
        midend_new_game(me);
        fe.colours = (rgb *)midend_colours(me, &fe.ncolours);
    }
    return self;
}

- (void)dealloc
{
    midend_free(me);
}

- (void)layoutSubviews
{
    int usable_height = self.frame.size.height;
    if (midend_wants_statusbar(me)) {
        usable_height -= 20;
        CGRect r = CGRectMake(0, usable_height, self.frame.size.width, 20);
        if (statusbar) {
            [statusbar setFrame:r];
        } else {
            statusbar = [[UILabel alloc] initWithFrame:r];
            [self addSubview:statusbar];
        }
    } else {
        if (statusbar) {
            [statusbar removeFromSuperview];
            statusbar = nil;
        }
    }
    extern const game filling;
    extern const game keen;
    extern const game solo;
    extern const game towers;
    extern const game undead;
    extern const game unequal;
    if (ourgame == &filling
     || ourgame == &keen
     || ourgame == &solo
     || ourgame == &towers
     || ourgame == &undead
     || ourgame == &unequal) {
        usable_height -= 40;
        int n = 9;
        const char *labels = "123456789";
        if (ourgame == &undead) {
            n = 3;
            labels = "GVZ";
        }
        for (int i = 0; i < n; i++) {
            CGRect r = CGRectMake(35*i, usable_height, 30, 40);
            if (buttons[i]) {
                [buttons[i] setFrame:r];
            } else {
                buttons[i] = [UIButton buttonWithType:UIButtonTypeRoundedRect];
                [buttons[i] addTarget:self action:@selector(keyButton:) forControlEvents:UIControlEventTouchUpInside];
                [buttons[i] setFrame:r];
                [self addSubview:buttons[i]];
                [buttons[i] setTitle:[NSString stringWithFormat:@"%c", labels[i]] forState:UIControlStateNormal];
            }
        }
    } else {
        for (int i = 0; i < NBUTTONS; i++) {
            if (buttons[i]) {
                [buttons[i] removeFromSuperview];
                buttons[i] = nil;
            }
        }
    }
    usable_frame = CGRectMake(0, 0, self.frame.size.width, usable_height);
    int w = self.frame.size.width * self.contentScaleFactor;
    int h = usable_height * self.contentScaleFactor;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    bitmap = CGBitmapContextCreate(NULL, w, h, 8, w*4, cs, kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(cs);
    midend_size(me, &w, &h, FALSE);
    midend_force_redraw(me);
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    CGContextDrawImage(context, usable_frame, image);
    CGImageRelease(image);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    touchTimer = [NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(handleTouchTimer:) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:touchTimer forMode:NSDefaultRunLoopMode];
    touchState = 1;
    touchX = p.x * self.contentScaleFactor;
    touchY = p.y * self.contentScaleFactor;
    touchButton = 0;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    int x = p.x * self.contentScaleFactor;
    int y = p.y * self.contentScaleFactor;
    if (touchState == 1) {
        if (abs(x - touchX) >= 10 || abs(y - touchY) >= 10) {
            [touchTimer invalidate];
            touchTimer = nil;
            midend_process_key(me, touchX, touchY, ButtonDown[touchButton]);
            touchState = 2;
        }
    }
    if (touchState == 2) {
        midend_process_key(me, x, y, ButtonDrag[touchButton]);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint p = [touch locationInView:self];
    int x = p.x * self.contentScaleFactor;
    int y = p.y * self.contentScaleFactor;
    if (touchState == 1) {
        midend_process_key(me, touchX, touchY, ButtonDown[touchButton]);
    }
    midend_process_key(me, x, y, ButtonUp[touchButton]);
    touchState = 0;
    [touchTimer invalidate];
    touchTimer = nil;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    touchState = 0;
    [touchTimer invalidate];
    touchTimer = nil;
}

- (void)handleTouchTimer:(NSTimer *)timer
{
    if (touchState == 1) {
        extern const game net;
        if (ourgame == &net) {
            touchButton = 2; // middle button
        } else {
            touchButton = 1; // right button
        }
        midend_process_key(me, touchX, touchY, ButtonDown[touchButton]);
        touchState = 2;
    }
}

- (void)keyButton:(UIButton *)sender
{
    for (int i = 0; i < NBUTTONS; i++) {
        if (sender == buttons[i]) {
            midend_process_key(me, -1, -1, [sender.currentTitle characterAtIndex:0]);
            break;
        }
    }
}

- (void)activateTimer
{
    if (timer != nil) {
        [timer invalidate];
    }
    timer = [NSTimer timerWithTimeInterval:0.02 target:self selector:@selector(timerFire:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)deactivateTimer
{
    [timer invalidate];
    timer = nil;
}

- (void)timerFire:(NSTimer *)timer
{
    midend_timer(me, 0.02);
}

@end

static void ios_draw_text(void *handle, int x, int y, int fonttype,
                          int fontsize, int align, int colour, char *text)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    CGContextSelectFont(gv.bitmap, "Helvetica", fontsize, kCGEncodingMacRoman);
    CGContextSetTextMatrix(gv.bitmap, CGAffineTransformMake(1, 0, 0, -1, 0, 0));
    CGContextSetRGBFillColor(gv.bitmap, fe->colours[colour][0], fe->colours[colour][1], fe->colours[colour][2], 1);
    CGPoint p = CGContextGetTextPosition(gv.bitmap);
    CGContextSetTextDrawingMode(gv.bitmap, kCGTextInvisible);
    CGContextShowText(gv.bitmap, text, strlen(text));
    CGPoint q = CGContextGetTextPosition(gv.bitmap);
    switch (align & (ALIGN_HLEFT|ALIGN_HCENTRE|ALIGN_HRIGHT)) {
        case ALIGN_HLEFT:
            break;
        case ALIGN_HCENTRE:
            x -= (q.x - p.x) / 2;
            break;
        case ALIGN_HRIGHT:
            x -= q.x - p.x;
            break;
    }
    switch (align & (ALIGN_VNORMAL|ALIGN_VCENTRE)) {
        case ALIGN_VNORMAL:
            break;
        case ALIGN_VCENTRE:
            y += fontsize / 2;
            break;
    }
    CGContextSetTextDrawingMode(gv.bitmap, kCGTextFill);
    // TODO: handle UTF-8 characters properly (Keen)
    CGContextShowTextAtPoint(gv.bitmap, x, y, text, strlen(text));
}

static void ios_draw_rect(void *handle, int x, int y, int w, int h, int colour)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    CGContextSetRGBFillColor(gv.bitmap, fe->colours[colour][0], fe->colours[colour][1], fe->colours[colour][2], 1);
    CGContextFillRect(gv.bitmap, CGRectMake(x, y, w, h));
}

static void ios_draw_line(void *handle, int x1, int y1, int x2, int y2, int colour)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    CGContextSetRGBStrokeColor(gv.bitmap, fe->colours[colour][0], fe->colours[colour][1], fe->colours[colour][2], 1);
    CGContextBeginPath(gv.bitmap);
    CGContextMoveToPoint(gv.bitmap, x1, y1);
    CGContextAddLineToPoint(gv.bitmap, x2, y2);
    CGContextStrokePath(gv.bitmap);
}

static void ios_draw_polygon(void *handle, int *coords, int npoints,
                             int fillcolour, int outlinecolour)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    CGContextSetRGBStrokeColor(gv.bitmap, fe->colours[outlinecolour][0], fe->colours[outlinecolour][1], fe->colours[outlinecolour][2], 1);
    CGContextBeginPath(gv.bitmap);
    CGContextMoveToPoint(gv.bitmap, coords[0], coords[1]);
    for (int i = 1; i < npoints; i++) {
        CGContextAddLineToPoint(gv.bitmap, coords[i*2], coords[i*2+1]);
    }
    CGPathDrawingMode mode = kCGPathStroke;
    if (fillcolour >= 0) {
        CGContextSetRGBFillColor(gv.bitmap, fe->colours[fillcolour][0], fe->colours[fillcolour][1], fe->colours[fillcolour][2], 1);
        mode = kCGPathFillStroke;
    }
    CGContextDrawPath(gv.bitmap, mode);
}

static void ios_draw_circle(void *handle, int cx, int cy, int radius,
                            int fillcolour, int outlinecolour)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    if (fillcolour >= 0) {
        CGContextSetRGBFillColor(gv.bitmap, fe->colours[fillcolour][0], fe->colours[fillcolour][1], fe->colours[fillcolour][2], 1);
        CGContextFillEllipseInRect(gv.bitmap, CGRectMake(cx-radius+1, cy-radius+1, radius*2-1, radius*2-1));
    }
    CGContextSetRGBStrokeColor(gv.bitmap, fe->colours[outlinecolour][0], fe->colours[outlinecolour][1], fe->colours[outlinecolour][2], 1);
    CGContextStrokeEllipseInRect(gv.bitmap, CGRectMake(cx-radius+1, cy-radius+1, radius*2-1, radius*2-1));
}

static void ios_draw_update(void *handle, int x, int y, int w, int h)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    [gv setNeedsDisplay];
}

static void ios_clip(void *handle, int x, int y, int w, int h)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    if (!fe->clipping) {
        CGContextSaveGState(gv.bitmap);
    }
    CGContextClipToRect(gv.bitmap, CGRectMake(x, y, w, h));
    fe->clipping = YES;
}

static void ios_unclip(void *handle)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    if (fe->clipping) {
        CGContextRestoreGState(gv.bitmap);
    }
    fe->clipping = NO;
}

static void ios_start_draw(void *handle)
{
}

static void ios_end_draw(void *handle)
{
}

static void ios_status_bar(void *handle, char *text)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    gv.statusbar.text = [NSString stringWithUTF8String:text];
}

struct blitter {
    int w, h;
    int x, y;
    CGImageRef img;
};

static blitter *ios_blitter_new(void *handle, int w, int h)
{
    blitter *bl = snew(blitter);
    bl->w = w;
    bl->h = h;
    bl->x = -1;
    bl->y = -1;
    bl->img = NULL;
    return bl;
}

static void ios_blitter_free(void *handle, blitter *bl)
{
    if (bl->img != NULL) {
        CGImageRelease(bl->img);
    }
    sfree(bl);
}

static void ios_blitter_save(void *handle, blitter *bl, int x, int y)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    if (bl->img != NULL) {
        CGImageRelease(bl->img);
    }
    bl->x = x;
    bl->y = y;
    CGImageRef bitmap = CGBitmapContextCreateImage(gv.bitmap);
    // Not certain why the y coordinate inversion is necessary here, but it is
    bl->img = CGImageCreateWithImageInRect(bitmap, CGRectMake(x, CGBitmapContextGetHeight(gv.bitmap)-y-bl->h, bl->w, bl->h));
    CGImageRelease(bitmap);
}

static void ios_blitter_load(void *handle, blitter *bl, int x, int y)
{
    frontend *fe = (frontend *)handle;
    GameView *gv = (__bridge GameView *)(fe->gv);
    if (x == BLITTER_FROMSAVED && y == BLITTER_FROMSAVED) {
        x = bl->x;
        y = bl->y;
    }
    CGContextDrawImage(gv.bitmap, CGRectMake(x, y, bl->w, bl->h), bl->img);
}

static char *ios_text_fallback(void *handle, const char *const *strings,
                               int nstrings)
{
    NSLog(@"TODO: text_fallback");
    return dupstr(strings[0]);
}

const struct drawing_api ios_drawing = {
    ios_draw_text,
    ios_draw_rect,
    ios_draw_line,
    ios_draw_polygon,
    ios_draw_circle,
    ios_draw_update,
    ios_clip,
    ios_unclip,
    ios_start_draw,
    ios_end_draw,
    ios_status_bar,
    ios_blitter_new,
    ios_blitter_free,
    ios_blitter_save,
    ios_blitter_load,
    NULL, NULL, NULL, NULL, NULL, NULL, /* {begin,end}_{doc,page,puzzle} */
    NULL, NULL,                        /* line_width, line_dotted */
    ios_text_fallback,
};      

void fatal(char *fmt, ...)
{
}

void frontend_default_colour(frontend *fe, float *output)
{
    output[0] = output[1] = output[2] = 0.8f;
}

void get_random_seed(void **randseed, int *randseedsize)
{
    time_t *tp = snew(time_t);
    time(tp);
    *randseed = (void *)tp;
    *randseedsize = sizeof(time_t);
}

void activate_timer(frontend *fe)
{
    GameView *gv = (__bridge GameView *)(fe->gv);
    [gv activateTimer];
}

void deactivate_timer(frontend *fe)
{
    GameView *gv = (__bridge GameView *)(fe->gv);
    [gv deactivateTimer];
}
