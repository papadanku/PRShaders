
/*
	Shared functions that process/generate data in the pixel shader
*/

#if !defined(REALITY_PIXEL)
	#define REALITY_PIXEL
	#undef INCLUDED_HEADERS
	#define INCLUDED_HEADERS

	float GetMax3(float3 Input)
	{
		return max(Input.x, max(Input.y, Input.z));
	}

	float GetMin3(float3 Input)
	{
		return max(Input.x, max(Input.y, Input.z));
	}

	float Desaturate(float3 Input)
	{
		return lerp(GetMin3(Input), GetMax3(Input), 1.0 / 2.0);
	}

	/*
		Hash function, optimized for instructions
		---
		C. Wyman and M. McGuire, “Hashed Alpha Testing,” 2017, [Online]. Available: http://www.cwyman.org/papers/i3d17_hashedAlpha.pdf
	*/
	float GetHash(float2 Input)
	{
		float2 H = 0.0;
		H.x = dot(Input, float2(17.0, 0.1));
		H.y = dot(Input, float2(1.0, 13.0));
		H = sin(H);
		return frac(1.0e4 * H.x * (0.1 + abs(H.y)));
	}

	/*
		GetGradientNoise(): https://iquilezles.org/articles/gradientnoise/
		GetProceduralTiles(): https://iquilezles.org/articles/texturerepetition
		GetQuintic(): https://iquilezles.org/articles/texture/

		The MIT License (MIT)

		Copyright (c) 2017 Inigo Quilez

		Permission is hereby granted, free of charge, to any person obtaining a copy of this
		software and associated documentation files (the "Software"), to deal in the Software
		without restriction, including without limitation the rights to use, copy, modify,
		merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
		permit persons to whom the Software is furnished to do so, subject to the following
		conditions:

		The above copyright notice and this permission notice shall be included in all copies
		or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
		INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
		PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
		HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
		CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
		OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
	*/

	float2 GetQuintic(float2 X)
	{
		return X * X * X * (X * (X * 6.0 - 15.0) + 10.0);
	}

	float GetValueNoise(float2 Tex)
	{
		float2 I = floor(Tex);
		float2 F = frac(Tex);
		float A = GetHash(I + float2(0.0, 0.0));
		float B = GetHash(I + float2(1.0, 0.0));
		float C = GetHash(I + float2(0.0, 1.0));
		float D = GetHash(I + float2(1.0, 1.0));
		float2 UV = GetQuintic(F);
		return lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
	}

	float GetGradient(float2 I, float2 F, float2 O)
	{
		// Get constants
		const float TwoPi = acos(-1.0) * 2.0;

		// Calculate random hash rotation
		float Hash = GetHash(I + O) * TwoPi;
		float2 HashSinCos = float2(sin(Hash), cos(Hash));

		// Calculate final dot-product
		return dot(HashSinCos, F - O);
	}

	float GetGradientNoise(float2 Input)
	{
		float2 I = floor(Input);
		float2 F = frac(Input);
		float A = GetGradient(I, F, float2(0.0, 0.0));
		float B = GetGradient(I, F, float2(1.0, 0.0));
		float C = GetGradient(I, F, float2(0.0, 1.0));
		float D = GetGradient(I, F, float2(1.0, 1.0));
		float2 UV = GetQuintic(F);
		float Noise = lerp(lerp(A, B, UV.x), lerp(C, D, UV.x), UV.y);
		return saturate((Noise * 0.5) + 0.5);
	}

	float4 GetProceduralTiles(sampler2D Source, float2 Tex)
	{
		// Sample variation pattern
		float Variation = GetValueNoise(Tex);

		// Compute index
		float Index = Variation * 8.0;
		float I = floor(Index);
		float F = frac(Index);

		// Offsets for the different virtual patterns
		float2 Offset1 = sin(float2(3.0, 7.0) * (I + 0.0));
		float2 Offset2 = sin(float2(3.0, 7.0) * (I + 1.0));

		// Compute derivatives for mip-mapping
		float2 Ix = ddx(Tex);
		float2 Iy = ddy(Tex);

		float4 Color1 = tex2Dgrad(Source, Tex + Offset1, Ix, Iy);
		float4 Color2 = tex2Dgrad(Source, Tex + Offset2, Ix, Iy);
		float Blend = dot(Color1.rgb - Color2.rgb, 1.0);
		return lerp(Color1, Color2, smoothstep(0.2, 0.8, F - (0.1 * Blend)));
	}

	float2 GetPixelSize(float2 Tex)
	{
		return abs(float2(ddx(Tex.x), ddy(Tex.y)));
	}

	int2 GetScreenSize(float2 Tex)
	{
		return 1.0 / GetPixelSize(Tex);
	}

	float GetAspectRatio(float2 ScreenSize)
	{
		return float(ScreenSize.y) / float(ScreenSize.x);
	}

	/*
		Convolutions
	*/

	float4 GetSpiralBlur(sampler Source, float2 Tex, float Bias)
	{
		// Initialize values
		float4 OutputColor = 0.0;
		float4 Weight = 0.0;

		// Get constants
		const float Pi2 = acos(-1.0) * 2.0;

		// Get texcoord data
		float2 ScreenSize = GetScreenSize(Tex);
		float Noise = Pi2 * GetGradientNoise((Tex * ScreenSize) * 0.25);
		float AspectRatio = GetAspectRatio(ScreenSize);

		float2 Rotation = 0.0;
		sincos(Noise, Rotation.y, Rotation.x);
		float2x2 RotationMatrix = float2x2(Rotation.x, Rotation.y, -Rotation.y, Rotation.x);

		float Shift = 0.0;
		for(int i = 1; i < 4; ++i)
		{
			for(int j = 0; j < 4 * i; ++j)
			{
				Shift = (Pi2 / (4.0 * float(i))) * float(j);
				float2 AngleShift = 0.0;
				sincos(Shift, AngleShift.x, AngleShift.y);
				AngleShift *= float(i);

				float2 Offset = mul(AngleShift, RotationMatrix);
				Offset.x *= AspectRatio;
				Offset *= Bias;
				OutputColor += tex2D(Source, Tex + (Offset * 0.01));
				Weight++;
			}
		}

		return OutputColor / Weight;
	}

	float2 GetHemiTex(float3 WorldPos, float3 WorldNormal, float3 HemiInfo, bool InvertY)
	{
		// HemiInfo: Offset x/y heightmapsize z / hemilerpbias w
		float2 HemiTex = 0.0;
		HemiTex.xy = ((WorldPos + (HemiInfo.z * 0.5) + WorldNormal).xz - HemiInfo.xy) / HemiInfo.z;
		HemiTex.y = (InvertY == true) ? 1.0 - HemiTex.y : HemiTex.y;
		return HemiTex;
	}

	// Gets radial light attenuation value for pointlights
	float GetLightAttenuation(float3 LightVec, float Attenuation)
	{
		return saturate(1.0 - dot(LightVec, LightVec) * Attenuation);
	}

#endif
