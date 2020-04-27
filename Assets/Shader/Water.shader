Shader "Unlit/Water"
{
	Properties 
	{
		_Color ("Water Color", Color) = (0.007,0.125,0.07,1)
		_SpecColor ("Specular Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range (0.01, 1)) = 9.5
		_ReflectColor ("Reflection Color", Color) = (1,1,1,0.5)
		_refractColor("Refract Color", Color) = (1,1,1,0.6)
		_FresnelPow ("Fresnel Pow", Range (0.01, 10)) = 1.0
		_uvTile("Normal_uvTile(xy,zw)",Vector) = (10.7,15.3,30.02,20.1)
		_Speed("Speed&Dir(xy,zw)",Vector) = (0.51,0.69,-0.31,-0.34)	
		_BumpMap ("Normalmap", 2D) = "bump" {}
		_BumpMapInt ("BumpMapInt", Range (0.01, 3)) = 1.0
	}
	SubShader 
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="false" "RenderType"="Transparent"}
		LOD 100
		Pass {  
		    Tags { "LightMode" = "ForwardBase" }  
		    Blend SrcAlpha OneMinusSrcAlpha 
		    ZWrite off
		    CGPROGRAM  
		    
		    #pragma vertex vert  
		    #pragma fragment frag  
		    #pragma multi_compile_fwdbase
			#include "UnityCG.cginc"
			#include "Lighting.cginc"    
			#include "AutoLight.cginc"  
		    #pragma target 3.0
		    
		    //#include "PBR_Input.cginc"  
		    sampler2D _BumpMap;

		    fixed4 _Color;
		    fixed4 _ReflectColor,_Speed,_uvTile,_shallowWaterColor,_refractColor;
		    half _Shininess , _FresnelPow; 
		    float _BumpMapInt;

		    struct appdata_t {
		        float4 vertex : POSITION;
		        float4 tangent : TANGENT;
		        float3 normal : NORMAL;
		        float4 texcoord : TEXCOORD0;
		        fixed4 color : COLOR;
		    };  
		    struct v2f {  
		        UNITY_POSITION(pos); 
		        float4 uv_BumpMap : TEXCOORD0;   
		        float3 worldPos : TEXCOORD1;
		        float4 worldNormal : TEXCOORD2; //w:fogfactor
		        float3 worldTangent : TEXCOORD3;
		        float3 worldBinormal : TEXCOORD4;
		        float4 viewDir : TEXCOORD5; //w: DirInscatterFogFactor
		        fixed4 vertColor : COLOR;
		        // UNITY_FOG_COORDS(5)
		    };  
		    
		    v2f vert(appdata_t v) {  
		        v2f o;                    
		        o.pos = UnityObjectToClipPos(v.vertex);  
		        o.vertColor = v.color;         
		        o.uv_BumpMap.xyzw = v.texcoord.xyxy * _uvTile;  
		        o.uv_BumpMap =  o.uv_BumpMap + _Speed * _Time.x;

		        o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
		        o.worldNormal.xyz = UnityObjectToWorldNormal(v.normal);
		        o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
		        fixed tangentSign = v.tangent.w * unity_WorldTransformParams.w;
		        o.worldBinormal = cross(o.worldNormal.xyz, o.worldTangent) * tangentSign;

		        float3 worldPosToCam = o.worldPos.xyz - _WorldSpaceCameraPos.xyz;
		        o.viewDir.xyz = normalize(-worldPosToCam);

		        //#if defined(_SHADER_LOD01) || defined(_SHADER_LOD02)       
		        //float2 heightFogFactor = GetExponentialHeightFogFactor(worldPosToCam);
		        //heightFogFactor = saturate(heightFogFactor);
		        //o.viewDir.w = heightFogFactor.x;
		        //o.worldNormal.w = heightFogFactor.y;
		        //#else
		        o.viewDir.w = 1.0;
		        o.worldNormal.w = 1.0; 
		        //#endif

		        return o;  
		    }  

		    uniform float _ReflectionScale;
		    
		    fixed4 frag(v2f i) : COLOR {  

		        fixed4 nor1 = tex2D(_BumpMap, i.uv_BumpMap.xy) ;
		        fixed4 nor2 = tex2D(_BumpMap, i.uv_BumpMap.zw + nor1.xy * 0.15) ;
		        // fixed4 nor = normalize(fixed4(nor1.rg + nor2.rg , nor1.b * nor2.b  , 1)); 
		        fixed3 tangentNormal = nor2.rgb * 2.0 - 1; 

		        tangentNormal.xy *= _BumpMapInt;

		        float3 worldNormal = tangentNormal.x * i.worldTangent + tangentNormal.y * i.worldBinormal +  i.worldNormal.xyz;  
		        worldNormal = normalize(worldNormal);
		        float3 worldViewDir = i.viewDir;  
		        float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));  

		        //fog parameters
		        float3 worldPosToCam = i.worldPos - _WorldSpaceCameraPos.xyz;
		        //#if defined(_SHADER_LOD01) || defined(_SHADER_LOD02)
		            float2 heightFogFactor = float2(i.viewDir.w,i.worldNormal.w);
		        //#else
		        //    float2 heightFogFactor = GetExponentialHeightFogFactor(worldPosToCam);
		        //#endif

		        // BlinnPong specular  
		        float3 H  = normalize (lightDir + worldViewDir);
		        half3 NoH = max (0, dot (worldNormal, H));       
		        fixed3 spec =  pow(NoH, _Shininess * 1280.0);
		    

		        fixed fresnel = 0.02 + 0.98 * pow(1.0 - saturate (dot(worldViewDir,worldNormal )),_FresnelPow);

		        fixed3 worldRefl = reflect(-worldViewDir, worldNormal);  

		        fixed4 reflCube =  UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, worldRefl, 1.0);
		        fixed3 reflCol =  DecodeHDR(reflCube, unity_SpecCube0_HDR);
		        fixed4 refrCube = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, refract(-worldViewDir, worldNormal, 0.3),1.0);
		        fixed3 refrCol = DecodeHDR(refrCube, unity_SpecCube0_HDR);
		        fixed4 col;  
		        col.rgb =  spec * _SpecColor.rgb + reflCol.rgb * fresnel * _ReflectColor.rgb  + refrCol.rgb * (1 - fresnel) * _refractColor.rgb ;  
		        col.rgb *=  _ReflectionScale;
		        col.rgb += _Color.rgb;

		        col.a = i.vertColor.a * (fresnel + _refractColor.a) * _Color.a;  
		        col.a = saturate(col.a);
		        
		        //fog
		        //APPLY_HEIGHT_FOG(worldPosToCam,heightFogFactor,col);
		        return col;
		    }  
		    ENDCG  
		}
	} 
}
