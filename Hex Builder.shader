Shader "Zebra North/Hex Builder"
{
    Properties
    {
        // Standard shader options.
        _MainTex("Albedo (RGB)", 2D) = "white" {}
        [HDR] _Color("Color", Color) = (1,1,1,1)
        [NoScaleOffset] _MetallicMap("Metallic Map", 2D) = "black" {}
        _Metallic("Metallic", Range(0,1)) = 0.0
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        _SmoothnessSource("Smoothness Source: Metallic Alpha - Albedo Alpha", Range(0, 1)) = 0.0
        [NoScaleOffset][Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        [NoScaleOffset]_EmissionMap("Emission Map", 2D) = "black" {}
        [HDR] _EmissionTint("Emission Tint", Color) = (0, 0, 0, 1)

        // Centre, y-axis scale, and rotation for the projection cylinder.
        _Centre("Centre", Vector) = (0, 0, 0, 0)
        _Height("Height", float) = 2
        _Rotation("Rotation", Vector) = (0, 0, 0, 0)

        // Hexagons.
        _Hexagons("Hexagons", Range(1, 100)) = 8
        _AspectRatio("Aspect Ratio", Float) = 1
        _Warp("Warp", Range(0, 1)) = 0
        _FadeWidth("Fade Width", Range(0, 1)) = 0.5

        // Animation time.
        t("Animation Time", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        Cull Off

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        #define PI 3.1415926535897932384626433832795

        struct Input
        {
            float2 uv_MainTex;
            float3 objectSpacePosition;
        };

        // Material.
        sampler2D _MainTex;
        float4 _Color;
        sampler2D _MetallicMap;
        float _Metallic;
        float _Glossiness;
        float SmoothnessSource;
        sampler2D _NormalMap;
        sampler2D _EmissionMap;
        float3 _EmissionTint;
        float _SmoothnessSource;

        // Hexagons.
        float _Hexagons;
        float _AspectRatio;
        float _Warp;
        float _FadeWidth;

        // Animation.
        float4 _Centre;
        float _Height;
        float3 _Rotation;
        float t;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        /**
         * Map a value from one range to another.
         *
         * @param value   The value to be remapped.
         * @param fromMin The minimum value of the input range.
         * @param fromMax The maximum value of the input range.
         * @param toMin   The minimum value of the output range.
         * @param toMax   The maximum value of the output range.
         *
         * @return Returns a value between toMin and toMax.
         */
        float map(float value, float fromMin, float fromMax, float toMin, float toMax)
        {
            float fromSpan = fromMax - fromMin;
            float toSpan = toMax - toMin;

            return (value - fromMin) / fromSpan * toSpan + toMin;
        }

        /**
         * Build a rotation matrix.
         *
         * @param roll  Rotation around the x axis in radians.
         * @param pitch Rotation around the y axis in radians.
         * @param yaw   Rotation around the z axis in radians.
         *
         * @return Returns a rotation matrix with the given Euler angles.
         */
        float3x3 rotationMatrix3d(float roll, float pitch, float yaw)
        {
            float sinRoll = sin(roll);
            float cosRoll = cos(roll);
            float sinPitch = sin(pitch);
            float cosPitch = cos(pitch);
            float sinYaw = sin(yaw);
            float cosYaw = cos(yaw);

            return float3x3(
                float3(cosRoll * cosPitch, cosRoll * sinPitch * sinYaw - sinRoll * cosYaw, cosRoll * sinPitch * cosYaw + sinRoll * sinYaw),
                float3(sinRoll * cosPitch, sinRoll * sinPitch * sinYaw + cosRoll * cosYaw, sinRoll * sinPitch * cosYaw - cosRoll * sinYaw),
                float3(-sinPitch, cosPitch * sinYaw, cosPitch * cosYaw));
        }



        /**
         * Vertex shader.
         *
         * @param appdata_full v See UnityCG.cginc.
         * @param Input        o The output to the surface shader.
         */
        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            float3 rotation = _Rotation / (2 * PI);
            o.objectSpacePosition = mul(((v.vertex - _Centre) / _Height).xyz, rotationMatrix3d(rotation.x, rotation.y, rotation.z));

            // Range: -1 to +1
            o.objectSpacePosition *= 2;
        }

        /**
         * The surface shader.
         *
         * @param Input                 IN The output from the vertex shader.
         * @param SurfaceOutputStandard o  See UnityPBSLighting.cginc.
         */
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo.
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;

            // Metallic.
            float4 metallicMap = tex2D(_MetallicMap, IN.uv_MainTex);
            o.Metallic = metallicMap.r * _Metallic;

            // Smoothness.
            o.Smoothness = lerp(c.a, metallicMap.a, _SmoothnessSource) * _Glossiness;

            // Normal.
            o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_MainTex));

            // Emission.
            o.Emission = tex2D(_EmissionMap, IN.uv_MainTex) * _EmissionTint;

            // Alpha.
            o.Alpha = c.a;

            float clipHeight = map(t, 0, 1, -1, 1);

            // Cylindrical projection:
            // UV.y = Object.y.  UV.x = Angle around a circle in the XZ plane.
            float2 cuv;
            cuv.x = atan2(IN.objectSpacePosition.z, IN.objectSpacePosition.x);
            cuv.x = map(cuv.x, -PI, PI, 0, 1);
            cuv.y = map(IN.objectSpacePosition.y, -1, 1, 0, 1);

            // Hexagons.

            // Get the input UV coordinate.
            float hexScale = _Hexagons + 4;
            float2 uv = cuv * hexScale;

            // Scale x so hexagons are 0..1 both horizontally and vertically.
            uv.x = uv.x * (2 / sqrt(3)) * _AspectRatio;

            int2 uvIndex;

            uvIndex.y = floor((uv.y + 1) / 3) * 2 + (frac((uv.y + 1) / 3) > 2.0 / 3 ? 1 : 0);
            uvIndex.x = floor((uv.x + (uvIndex.y & 1)) / 2);

            float2 hexUv = uv - uvIndex * float2(2, 1.5);

            if ((uvIndex.y & 1) == 0)
            {
                hexUv.x -= 1;

                if (2 * (abs(hexUv.y) - 0.5) > (1 - abs(hexUv.x)))
                {
                    if (hexUv.x > 0)
                        ++uvIndex.x;

                    uvIndex.y += sign(hexUv.y);
                }
            }

            // Recalculate uv so it is relative to the hexagon centre;
            hexUv = uv - uvIndex * float2(2, 1.5);
            hexUv.x -= 1 - (uvIndex.y & 1);

            float fadeWidth = _FadeWidth;
            float2 centrePos = (uvIndex * float2(2, 1.5) / hexScale);
            float threshold = t * (1 + 1 / hexScale + fadeWidth) - fadeWidth;

            float mask = 1 - ((lerp(centrePos.y, cuv.y, _Warp)) - threshold) / fadeWidth;


            // Clip the hexagons.
            // Calculate the distance between the hex index and the centre.
            clip(-2 * (abs(hexUv.y) - mask * 0.5) + (mask - abs(hexUv.x)));
            clip(mask - max(abs(hexUv.x), abs(hexUv.y)));
        }
        ENDCG
    }
    FallBack "Diffuse"
}
