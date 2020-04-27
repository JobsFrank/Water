Shader "Test/Water"
{
	 Properties
    {
        _CubeMap("CubeMap", CUBE) = ""{}
		_MainTex ("主帖图", 2D) = "white" {}
		_NoiseTex("水流扰动纹理", 2D) = "white" {}
		_Color("颜色",Color) = (1,1,1,1)
		_Light("亮度", Range(0, 10)) = 2
		_Intensity("扰动强度", float) = 0.1
		_XSpeed("扰动X轴速度", float) = 0.1
		_YSpeed("扰动Y轴速度", float) = 0.1
        _FresnelScale("菲涅尔反射强度", Float) = 0.5
		_Specular("高光阈值", float) = 0.03
		_Gloss("漫反射值-配合高光阈值", float) = 4.7
		_SpecColor ("高光颜色", color) = (0.4,0.4,0.4,1)
		_LightDir("光照方向", vector) = (0, 0, 0, 0)
    }
    SubShader
    {
		Tags { "IgnoreProjector"="True" "Queue"="Transparent" "RenderType"="Transparent"}

		Pass
		{
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			#include "UnityCG.cginc"
 
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 TW0:TEXCOORD2;
				float4 TW1:TEXCOORD3;
				float4 TW2:TEXCOORD4;
				float4 color : COLOR;
				float3 normal:NORMAL;
			};
 
			uniform sampler2D _MainTex;
			uniform samplerCUBE _CubeMap;
			uniform float4 _MainTex_ST;
			uniform sampler2D _NoiseTex;
			uniform float4 _Color;
			uniform float _Light;
			uniform float _Intensity;
			uniform float _XSpeed;
			uniform float _YSpeed;
			uniform half _Specular;
			uniform fixed _Gloss;
			uniform half4 _LightDir;
			uniform half4 _SpecColor;
			uniform half _FresnelScale;

			v2f vert(appdata_full v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);

				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				fixed tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
				o.normal = worldNormal;
				o.TW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.TW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.TW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
				o.color = v.color;
				return o;
			}
 
			fixed4 frag(v2f i) : SV_Target
			{
				//根据时间和偏移速度获取噪音图的颜色作为uv偏移
				fixed4 noise_col = tex2D(_NoiseTex, i.uv + fixed2(_Time.y*_XSpeed, _Time.y*_YSpeed));
				//计算uv偏移的颜色和亮度和附加颜色计算
				fixed4 col = tex2D(_MainTex, i.uv + _Intensity * noise_col.rg)*_Light*_Color;
				i.normal *= noise_col.rgb;
				//采样反射天空盒
				half3 worldPos = half3(i.TW0.w, i.TW1.w, i.TW2.w);

				half3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				half3 refl = reflect(-viewDir, i.normal);

				half vdn = saturate(pow(dot(viewDir, i.normal), _FresnelScale));

				col.rgb = lerp(texCUBE(_CubeMap, refl), col.rgb, vdn);
				half3 h = normalize(viewDir - normalize(_LightDir.xyz));
				fixed ndh = max(0, dot(i.normal, h));

				col += _Gloss*pow(ndh, _Specular*128.0)*_SpecColor;
				col.a = _Color.a;
				UNITY_APPLY_FOG(i.fogCoord, col);
				
				return col;
			}
			ENDCG
		}
    }
	FallBack "Diffuse"
}
