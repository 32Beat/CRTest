//
//  CRView.m
//  CRTest
//
//  Created by 32BT on 26/02/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "CRView.h"

@interface CRView ()
{
	IBOutlet NSButton *mButton;
	IBOutlet NSSlider *mSlider;
	IBOutlet NSTextField *mLabel;
}
@end

// convenience
#define HSB(h, s, b) \
[NSColor colorWithCalibratedHue:h/360.0 saturation:s brightness:b alpha:1.0]

// impulse train
static double SRC[] = { 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0 };

////////////////////////////////////////////////////////////////////////////////
@implementation CRView
////////////////////////////////////////////////////////////////////////////////

- (IBAction) didAdjustButton:(NSButton *)button
{
	double C = mButton.state;

	// switch between impulse and edge
	SRC[3] = 1.0;
	SRC[4] = C;
	SRC[5] = C;
	SRC[6] = C;
	SRC[7] = C;

	[self setNeedsDisplay:YES];
}

////////////////////////////////////////////////////////////////////////////////

- (IBAction) didAdjustSlider:(NSSlider *)slider
{
	[mLabel setStringValue:[NSString stringWithFormat:@"%.4f", slider.floatValue]];
	[self setNeedsDisplay:YES];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

- (void)drawRect:(NSRect)dirtyRect
{
	[[NSColor whiteColor] set];
	NSRectFill(dirtyRect);
	
	[self adjustOrigin];
	
	[HSB(0.0, 0.0, 0.9) set];
	[self drawVerticalLineAt:-3.0];
	[self drawVerticalLineAt:-2.0];
	[self drawVerticalLineAt:-1.0];
	[self drawVerticalLineAt:+1.0];
	[self drawVerticalLineAt:+2.0];
	[self drawVerticalLineAt:+3.0];
	[self drawHorizontalLineAt:+0.5];
	[HSB(0.0, 0.0, 0.75) set];
	[self drawHorizontalLineAt:+1.0];
	
	[[NSColor blackColor] set];
	[self drawHorizontalLineAt:0.0];
	[self drawVerticalLineAt:0.0];

	// draw elements
	[[NSColor darkGrayColor] set];
	[self drawSinc:2];
	
	[[NSColor lightGrayColor] set];
	[self drawSinc:3];
	
	[[NSColor blueColor] set];
	[self drawCR1];

/*
	// CR2 should be equivalent to CR1
	[[NSColor redColor] set];
	[self drawDCR2];
//*/
/*
	// DCR2 derivative of CR 
	[[NSColor redColor] set];
	[self drawDCR2];
//*/
	
	// draw frame
	[[NSColor blackColor] set];
	NSFrameRect(self.bounds);
}

////////////////////////////////////////////////////////////////////////////////

- (void) adjustOrigin
{
	NSRect B = self.bounds;
	CGFloat x = 0.50 * B.size.width;
	CGFloat y = 0.25 * B.size.height;
	B.origin.x = -(floor(x)+0.5);
	B.origin.y = -(floor(y)+0.5);
	self.bounds = B;
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawHorizontalLineAt:(CGFloat)y
{
	NSRect B = self.bounds;
	y = round(y*B.size.height/2.0);
	
	NSPoint X1 = { NSMinX(B), y };
	NSPoint X2 = { NSMaxX(B), y };
	[NSBezierPath strokeLineFromPoint:X1 toPoint:X2];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawVerticalLineAt:(CGFloat)x
{
	NSRect B = self.bounds;
	x = round(x*B.size.width/6.0);

	NSPoint Y1 = { x, NSMinY(B) };
	NSPoint Y2 = { x, NSMaxY(B) };
	[NSBezierPath strokeLineFromPoint:Y1 toPoint:Y2];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawPath:(NSBezierPath *)path
{
	NSRect B = self.bounds;
	
	NSAffineTransform *T = [NSAffineTransform transform];
	[T scaleXBy:B.size.width / 6.0 yBy:B.size.height / 2.0];
	
	[[T transformBezierPath:path] stroke];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static double sinc(double x, long N)
{
	double w = sin(x*M_PI/N)/(x*M_PI/N);
	double s = sin(x*M_PI)/(x*M_PI);
	return w * s;
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawSinc:(long)N
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:(NSPoint){ -N, 0.0 }];
	
	long R = 0.5 * self.bounds.size.width / 3.0;
	for (long n=-R; n<=R; n++)
	{
		if (n != 0)
		{
			double x = 1.0 * N * n / R;
			double y = sinc(x, N);
/*
			double y1 = sinc(x-0.0000001, N);
			double y2 = sinc(x+0.0000001, N);
			y = (y2-y1)/0.0000002;
//*/
			[path lineToPoint:(NSPoint){ x, y }];
		}
	}

	[self drawPath:path];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static NSBezierPath *NSBezierPathFromCR(double a, double x, double *Y)
{
	double d1 = Y[2] - Y[0];
	double d2 = Y[3] - Y[1];
	
	d1 *= a;
	d2 *= a;
	
	double P1 = Y[1];
	double C1 = Y[1] + d1;
	double C2 = Y[2] - d2;
	double P2 = Y[2];

	x = floor(x);

	NSBezierPath *path = [NSBezierPath new];
	
	[path moveToPoint:(NSPoint){ x+(0.0/3.0), P1 }];
	
	[path curveToPoint:(NSPoint){ x+(3.0/3.0), P2 }
		 controlPoint1:(NSPoint){ x+(1.0/3.0), C1 }
		 controlPoint2:(NSPoint){ x+(2.0/3.0), C2 }];
	
	return path;
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawCR1
{
	double a = mSlider.doubleValue;
	
	[self drawPath:NSBezierPathFromCR(a, -2.0, &SRC[0])];
	[self drawPath:NSBezierPathFromCR(a, -1.0, &SRC[1])];
	[self drawPath:NSBezierPathFromCR(a, +0.0, &SRC[2])];
	[self drawPath:NSBezierPathFromCR(a, +1.0, &SRC[3])];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
static double Bezier(double t, double P1, double C1, double C2, double P2)
{
	double d = P1;
	double c = 3*(C1-P1);
	double b = 3*(C2-C1) - c;
	double a = (P2-P1) - b - c;

	return ((a*t+b)*t+c)*t+d;
}
*/
////////////////////////////////////////////////////////////////////////////////

static double Bezier(double t, double P1, double C1, double C2, double P2)
{
	P1 += t * (C1 - P1);
	C1 += t * (C2 - C1);
	C2 += t * (P2 - C2);
	
	P1 += t * (C1 - P1);
	C1 += t * (C2 - C1);

	P1 += t * (C1 - P1);

	return P1;
}

////////////////////////////////////////////////////////////////////////////////

static double CRCompute
(double a, double x, double Y0, double Y1, double Y2, double Y3)
{
	double d1 = (Y2 - Y0) * a;
	double d2 = (Y3 - Y1) * a;
	return Bezier(x, Y1, Y1+d1, Y2-d2, Y2);
}

////////////////////////////////////////////////////////////////////////////////

static double CRComputePtr(double a, double x, double *Y)
{
	Y += (int)x;
	x -= trunc(x);
	return CRCompute(a, x, Y[0], Y[1], Y[2], Y[3]);
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawCR2
{
	double a = mSlider.doubleValue;
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:(NSPoint){ -2.0, 0.0 }];
	
	long R = 0.5 * self.bounds.size.width / 3.0;
	for (long n=-R; n<=R; n++)
	{
		if (n != 0)
		{
			double x = 2.0 * n / R;
			double y = CRComputePtr(a, x + 2.0, SRC);

			[path lineToPoint:(NSPoint){ x, y }];
		}
	}

	[self drawPath:path];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawDCR2
{
	double a = mSlider.doubleValue;
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:(NSPoint){ -2.0, 0.0 }];
	
	long R = 0.5 * self.bounds.size.width / 3.0;
	for (long n=-R; n<=R; n++)
	{
		if (n != 0)
		{
			double x = 2.0 * n / R;
			double x1 = x-0.00001;
			double x2 = x+0.00001;
			double y1 = CRComputePtr(a, x1 + 2.0, SRC);
			double y2 = CRComputePtr(a, x2 + 2.0, SRC);
			double y = (y2-y1)/(x2-x1);

			[path lineToPoint:(NSPoint){ x, y }];
		}
	}

	[self drawPath:path];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////












