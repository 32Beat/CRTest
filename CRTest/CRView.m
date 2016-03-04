//
//  CRView.m
//  CRTest
//
//  Created by 32BT on 26/02/16.
//  Copyright © 2016 32BT. All rights reserved.
//

#import "CRView.h"
#import <Accelerate/Accelerate.h>

@interface CRView ()
{
	IBOutlet NSButton *mButton;
	IBOutlet NSSlider *mSlider;
	IBOutlet NSTextField *mLabel;
}
@end

// convenience
#define GRAPH_X_MIN 	(-3.5)
#define GRAPH_X_MAX 	(+3.5)
#define GRAPH_Y_MIN 	(-0.5)
#define GRAPH_Y_MAX 	(+1.5)
#define GRAPH_W 		(GRAPH_X_MAX - GRAPH_X_MIN)
#define GRAPH_H 		(GRAPH_Y_MAX - GRAPH_Y_MIN)

#define HSB(h, s, b) \
[NSColor colorWithCalibratedHue:h/360.0 saturation:s brightness:b alpha:1.0]



// impulse train
static double SRC[] = { 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0 };

////////////////////////////////////////////////////////////////////////////////
@implementation CRView
////////////////////////////////////////////////////////////////////////////////

- (IBAction) didAdjustButton:(NSButton *)button
{
	int selectionIndex = [mButton.objectValue intValue];
	
	// switch between impulse, edge, or random samples
	SRC[0] = 0.0;
	SRC[1] = 0.0;
	SRC[2] = 0.0;
	SRC[3] = 0.0;
	SRC[4] = 1.0;
	SRC[5] = 0.0;
	SRC[6] = 0.0;
	SRC[7] = 0.0;
	SRC[8] = 0.0;

	if (selectionIndex == 1)
	{
		double V = 1.0;
		SRC[4] = V;
		SRC[5] = V;
		SRC[6] = V;
		SRC[7] = V;
		SRC[8] = V;
	}
	else
	if (selectionIndex == 2)
	{
		for (int n=1; n!=8; n++) \
		{ SRC[n] = 1.0 * random()/RAND_MAX; }
		
		// Replicate edge for interpolation
		SRC[0] = SRC[1];
		SRC[8] = SRC[7];
	}
	
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
	
	//----- draw grid
	[HSB(0.0, 0.0, 0.9) set];
	[self drawGrid];
	[HSB(0.0, 0.0, 0.6) set];
	[self drawHorizontalLineAt:+1.0];
	
	//----- draw samples for the "random" selection
	if ([mButton.objectValue intValue] == 2)
	{
		[HSB(0.0, 0.4, 0.95) set];
		[self drawSamples];
	}
	
	//----- draw axis
	[[NSColor blackColor] set];
	[self drawVerticalLineAt:0.0];
	[self drawHorizontalLineAt:0.0];

	//----- draw curves
	[[NSColor darkGrayColor] set];
	[self drawSinc:2];
	
	[[NSColor lightGrayColor] set];
	[self drawSinc:3];
	
	[[NSColor redColor] set];
	[self drawLanczosInterpolation];

	[HSB(200.0, 0.5, 0.95) set];
	[self drawLM1];

	[[NSColor blueColor] set];
	[self drawCR1];
	
	//----- draw frame
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

- (void) drawGrid
{
	for (long n=-3; n!=4; n++)
	{ [self drawVerticalLineAt:n]; }
	[self drawHorizontalLineAt:+0.5];
	[self drawHorizontalLineAt:+1.0];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawSamples
{
	NSBezierPath *path = [NSBezierPath new];
	[path setLineWidth:3.0];
	
	for (long n=1; n!=8; n++)
	{
		[path moveToPoint:(NSPoint){ n-4.0, 0.0 }];
		[path lineToPoint:(NSPoint){ n-4.0, SRC[n] }];
		[self drawPath:path];
		[path removeAllPoints];
	}
	
	path = nil;
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawHorizontalLineAt:(CGFloat)y
{
	NSRect B = self.bounds;
	y = round(y*B.size.height/GRAPH_H);
	
	NSPoint X1 = { NSMinX(B), y };
	NSPoint X2 = { NSMaxX(B), y };
	[NSBezierPath strokeLineFromPoint:X1 toPoint:X2];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawVerticalLineAt:(CGFloat)x
{
	NSRect B = self.bounds;
	x = round(x*B.size.width/GRAPH_W);

	NSPoint Y1 = { x, NSMinY(B) };
	NSPoint Y2 = { x, NSMaxY(B) };
	[NSBezierPath strokeLineFromPoint:Y1 toPoint:Y2];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawPath:(NSBezierPath *)path
{
	NSRect B = self.bounds;
	
	NSAffineTransform *T = [NSAffineTransform transform];
	[T scaleXBy:B.size.width / GRAPH_W yBy:B.size.height / GRAPH_H];
	
	[[T transformBezierPath:path] stroke];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static double sinc(double x, double N)
{
	if (x == 0.0) return 1.0;
	
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
		double x = 1.0 * N * n / R;
		double y = sinc(x, N);
/*
		double y1 = sinc(x-0.0000001, N);
		double y2 = sinc(x+0.0000001, N);
		y = (y2-y1)/0.0000002;
//*/
		[path lineToPoint:(NSPoint){ x, y }];
	}

	[self drawPath:path];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
	NSBezierPathFromCR
	------------------
	Create an interpolating NSBezierPath for the segment x+1.0 to x+2.0,
	using four sample points at { x+0.0, x+1.0, x+2.0, x+3.0 }
	
	the resulting x co-ordinates are set in one-third intervals to correspond 
	with the regular spaced grid of sampling. This results in x(t) = t
	
	the y co-ordinates are set according to catmull-rom tangents, using 
	"tension" factor "a". Because x is regular and constant, the tangents
	are strictly catmull-rom for a = 1.0/3.0 only.
*/
////////////////////////////////////////////////////////////////////////////////

static NSBezierPath *NSBezierPathFromCR(double a, double x, double *Y)
{
	// compute tangent for x + 1.0 using neighboring samples
	double d1 = a * (Y[2] - Y[0]) / 2.0;
	// compute tangent for x + 2.0 using neighboring samples
	double d2 = a * (Y[3] - Y[1]) / 2.0;

	// ensure segment starts at integral offset
	x = floor(x);
	
	// set segment endpoints P and control points C
	NSPoint P1 = { x + (0.0/3.0), Y[1] };
	NSPoint C1 = { x + (1.0/3.0), Y[1]+d1 };
	NSPoint C2 = { x + (2.0/3.0), Y[2]-d2 };
	NSPoint P2 = { x + (3.0/3.0), Y[2] };

	// create corresponding path
	NSBezierPath *path = [NSBezierPath new];
	
	[path moveToPoint:P1];
	[path curveToPoint:P2
		 controlPoint1:C1
		 controlPoint2:C2];
	
	return path;
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawCR1
{
	double a = mSlider.doubleValue;
	
	[self drawPath:NSBezierPathFromCR(a, -3.0, &SRC[0])];
	[self drawPath:NSBezierPathFromCR(a, -2.0, &SRC[1])];
	[self drawPath:NSBezierPathFromCR(a, -1.0, &SRC[2])];
	[self drawPath:NSBezierPathFromCR(a, +0.0, &SRC[3])];
	[self drawPath:NSBezierPathFromCR(a, +1.0, &SRC[4])];
	[self drawPath:NSBezierPathFromCR(a, +2.0, &SRC[5])];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
	Local monotone interpolation (no overshoot, useful for interaction purposes)
*/
static NSBezierPath *NSBezierPathFromLM(double a, double x, double *Y)
{
	double d1 = (Y[1] - Y[0]);
	double d2 = (Y[2] - Y[1]);
	double d3 = (Y[3] - Y[2]);
	
	if ((d1 < 0.0)==(d2 < 0.0))
	{ d1 = a * (fabs(d1)<fabs(d2)?d1:d2); }
	else
	{ d1 = 0.0; }
	
	if ((d2 < 0.0)==(d3 < 0.0))
	{ d2 = a * (fabs(d2)<fabs(d3)?d2:d3); }
	else
	{ d2 = 0.0; }
	

	x = floor(x);

	// set segment endpoints P and control points C
	NSPoint P1 = { x + (0.0/3.0), Y[1] };
	NSPoint C1 = { x + (1.0/3.0), Y[1]+d1 };
	NSPoint C2 = { x + (2.0/3.0), Y[2]-d2 };
	NSPoint P2 = { x + (3.0/3.0), Y[2] };

	// create corresponding path
	NSBezierPath *path = [NSBezierPath new];
	
	[path moveToPoint:P1];
	[path curveToPoint:P2
		 controlPoint1:C1
		 controlPoint2:C2];
	
	return path;
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawLM1
{
	double a = mSlider.doubleValue;
	
	[self drawPath:NSBezierPathFromLM(a, -3.0, &SRC[0])];
	[self drawPath:NSBezierPathFromLM(a, -2.0, &SRC[1])];
	[self drawPath:NSBezierPathFromLM(a, -1.0, &SRC[2])];
	[self drawPath:NSBezierPathFromLM(a, +0.0, &SRC[3])];
	[self drawPath:NSBezierPathFromLM(a, +1.0, &SRC[4])];
	[self drawPath:NSBezierPathFromLM(a, +2.0, &SRC[5])];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////
/*
	Bezier
	------
	Compute Bezier value using deCasteljau

	polynomial version would be:
	
		double d = P1;
		double c = 3*(C1-P1);
		double b = 3*(C2-C1) - c;
		double a = (P2-P1) - b - c;

		return ((a*t+b)*t+c)*t+d;
*/

double Bezier(double t, double P1, double C1, double C2, double P2)
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

static double CRCompute(double a, double x, double *Y)
{
	Y += (int)x;
	x -= trunc(x);
	
	double Y0 = Y[0];
	double Y1 = Y[1];
	double Y2 = Y[2];
	double Y3 = Y[3];
	
	double d1 = a * (Y2 - Y0) / 2.0;
	double d2 = a * (Y3 - Y1) / 2.0;

	return Bezier(x, Y1, Y1+d1, Y2-d2, Y2);
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawCR2
{
	double a = mSlider.doubleValue;
	
	NSBezierPath *path = [NSBezierPath bezierPath];

	double x = 0.0;
	double y = CRCompute(a, x, SRC);
	[path moveToPoint:(NSPoint){ x-2.0, y }];
	
	long R = self.bounds.size.width / 3.0;
	for (long n=1; n<=R; n++)
	{
		x = 4.0 * n / R;
		y = CRCompute(a, x, SRC);
		[path lineToPoint:(NSPoint){ x-2.0, y }];
	}

	[self drawPath:path];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawNodes
{
	double a = mSlider.doubleValue;

	static const double X[] = { -2.0, -1.0, 0.0, 1.0, 2.0 };
	for (int n=0; n!=4; n++)
	{
		double Y0 = SRC[n+0];
		double Y1 = SRC[n+1];
		double Y2 = SRC[n+2];

		double d = a * (Y2 - Y0) / 2.0;
		
		NSPoint P1 = { X[n]-1.0/3.0, Y1 - d };
		NSPoint P2 = { X[n]+1.0/3.0, Y1 + d };
		
		NSBezierPath *path = [NSBezierPath new];
		[path moveToPoint:P1];
		[path lineToPoint:P2];
		[self drawPath:path];
	}
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static double interpolateWithKernel(double (*kernelFunction)(double, double), double a, double x, double *Y)
{
	Y += (int)x;
	x -= trunc(x);

	double W0 = kernelFunction(-1.0-x, a);
	double W1 = kernelFunction(+0.0-x, a);
	double W2 = kernelFunction(+1.0-x, a);
	double W3 = kernelFunction(+2.0-x, a);
	
	double y =
	W0 * Y[0] +
	W1 * Y[1] +
	W2 * Y[2] +
	W3 * Y[3];
	
	return y / (W0 + W1 + W2 + W3);
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawInterpolation:(double(*)(double, double))kernelFunction
{
	double a = mSlider.doubleValue;
	[self drawInterpolation:kernelFunction withParameter:a];
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawInterpolation:(double(*)(double, double))kernelFunction withParameter:(double)a
{
	NSBezierPath *path = [NSBezierPath bezierPath];
	
	double x = 0.0;
	double y = interpolateWithKernel(kernelFunction, a, x, SRC);
	
	[path moveToPoint:(NSPoint){ x-3.0, y }];
	
	long R = self.bounds.size.width / 3.0;
	for (long n=1; n<=R; n++)
	{
		x = 6.0 * n / R;
		y = interpolateWithKernel(kernelFunction, a, x, SRC);

		[path lineToPoint:(NSPoint){ x-3.0, y }];
	}

	[self drawPath:path];
	
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawLanczosInterpolation
{
	[self drawInterpolation:sinc withParameter:2.0];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark
////////////////////////////////////////////////////////////////////////////////

static double BezierKernel(double x, double a)
{
	a *= 0.5;

	x = fabs(x);

	if (x < 1.0)
	{
		return Bezier(x, 1.0, 1.0, +a, 0.0);
	}
	else
	if (x < 2.0)
	{
		x -= 1.0;
		return Bezier(x, 0.0, -a, 0.0, 0.0);
	}
	
	return 0;
}

////////////////////////////////////////////////////////////////////////////////

- (void) drawBezierKernelInterpolation
{
	[self drawInterpolation:BezierKernel];
}

////////////////////////////////////////////////////////////////////////////////
@end
////////////////////////////////////////////////////////////////////////////////












