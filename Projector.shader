Shader "Projector/Unlit/ProjectorCookieTransparent"
{
    Properties
    {
        _ShadowTex ("Cookie (RGBA)", 2D) = "white" {}
        _FalloffTex ("Falloff (A)", 2D) = "white" {}
        _Tint ("Tint Color", Color) = (1,1,1,1)
        _ShadowLevel ("Intensity", Range(0,1)) = 1
        _HorizontalFade ("Horizontal Fade", Range(0,1)) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
        }

        Pass
        {
            ZWrite Off
            ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            ColorMask RGBA
            Offset -1, -1

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _ShadowTex;
            sampler2D _FalloffTex;
            float4 _Tint;
            float _ShadowLevel;
            float _HorizontalFade;

            float4x4 unity_Projector;
            float4x4 unity_ProjectorClip;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uvProj : TEXCOORD0;
                float4 uvClip : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uvProj = mul(unity_Projector, v.vertex);
                o.uvClip = mul(unity_ProjectorClip, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Projected UVs (cookie)
                float2 uv = i.uvProj.xy / i.uvProj.w;

                // Projector clip space → 0–1 UVs (THIS WAS THE BUG)
                float2 uvFalloff = i.uvClip.xy / i.uvClip.w;
                uvFalloff = uvFalloff * 0.5 + 0.5;

                // Kill tiling / out-of-bounds
                if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1)
                    discard;

                if (uvFalloff.x < 0 || uvFalloff.x > 1 || uvFalloff.y < 0 || uvFalloff.y > 1)
                    discard;

                fixed4 cookie = tex2D(_ShadowTex, uv) * _Tint;
                fixed falloff = tex2D(_FalloffTex, uvFalloff).a;

                // Horizontal fade (X axis only)
                if (_HorizontalFade > 0)
                {
                    float fade = 1.0 - saturate(abs(uv.x - 0.5) * 2.0);
                    falloff *= lerp(1.0, fade, _HorizontalFade);
                }

                cookie.a *= falloff * _ShadowLevel;

                return cookie;
            }

            ENDCG
        }
    }
}
