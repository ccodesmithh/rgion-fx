#ifdef IS_IRIS
    uniform float currentPlayerHealth;
    uniform float maxPlayerHealth;
    uniform float oneHeart;
    uniform float threeHeart;

    uniform float CriticalDamageTaken;
    uniform float MinorDamageTaken;
#else
    uniform bool isDead;
#endif

uniform float rainStrength;
uniform float exitWater;
uniform float enterWater;
uniform float exitLava;
// uniform float exitPowderSnow;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

// uniform float currentPlayerHunger;
// uniform float maxPlayerHunger;

// uniform float currentPlayerArmor;
// uniform float maxPlayerArmor;

// uniform float currentPlayerAir;
// uniform float maxPlayerAir;

// uniform bool is_sneaking;
// uniform bool is_sprinting;
// uniform bool is_hurt;
// uniform bool is_invisible;
// uniform bool is_burning;

// uniform bool is_on_ground;
// uniform bool isSpectator;

void applyGameplayEffects(inout vec3 color, in vec2 texcoord, float noise){
   
    // detect when health is zero
    #ifdef IS_IRIS
        bool isDead = currentPlayerHealth * maxPlayerHealth <= 0.0 && currentPlayerHealth > -1;
    #else
        float oneHeart = 0.0;
        float threeHeart = 0.0;
    #endif

    float distortmask = 0.0;
    float vignette = sqrt(clamp(dot(texcoord*2.0 - 1.0, texcoord*2.0 - 1.0) * 0.5, 0.0, 1.0));

    //////////////////////// DAMAGE DISTORTION /////////////////////
    #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT   
        float heartBeat = (pow(sin(frameTimeCounter * 15)*0.5+0.5,2.0)*0.2 + 0.1) ;
        
        // apply low health distortion effects
        float damageDistortion = vignette * noise * heartBeat * threeHeart;
        
        // apply critical hit distortion effect
        damageDistortion = mix(damageDistortion, vignette * (0.5 + noise), CriticalDamageTaken) * MOTION_AMOUNT;
        
        // apply death distortion effect
        distortmask = isDead ? vignette * (0.7 + noise*0.3) : damageDistortion;
    #endif
    //////////////////////// WATER DISTORTION /////////////////////
    #if defined WATER_ON_CAMERA_EFFECT
        if(exitWater > 0.0){
            vec3 scale = vec3(1.0,1.0,0.0);
            bool eyeInWater = isEyeInWater == 1;
            scale.xy = (eyeInWater ? vec2(0.3) : vec2(0.5, 0.25 + (exitWater*exitWater)*0.25 ) ) * vec2(aspectRatio,1.0);
            scale.z = eyeInWater ? 0.0 : exitWater;


            float waterDrops = texture(noisetex, (texcoord - vec2(0.0, scale.z)) * scale.xy).r ;
            if(eyeInWater) waterDrops = 0.0;
            if(isEyeInWater == 0 && exitWater > 0.0) waterDrops = sqrt(min(max(waterDrops - (1.0-sqrt(exitWater))*0.7,0.0) * (1.0 + exitWater),1.0)) * 0.3;

            // apply distortion effects for exiting water and under water
            distortmask = max(distortmask, waterDrops);
        }
        if(enterWater > 0.0){
            vec2 zoomTC = 0.5 + (texcoord - 0.5) * (1.0 - (1.0-sqrt(1.0-enterWater)) );
            float waterSplash = texture(noisetex, zoomTC * vec2(aspectRatio,1.0)).r * (1.0-enterWater);

            distortmask = max(distortmask, waterSplash);
        }
    #endif
    //////////////////////// RAIN DROPLETS /////////////////////
    #ifdef RAIN_DROPLETS_SCREEN
        if (rainStrength > 0.01) {
            // depth-based occlusion: vanish when close to blocks or underwater
            float rawDepth = texture(depthtex1, texcoord * RENDER_SCALE).r;
            float linearDepth = ld(rawDepth);
            float depthFade = smoothstep(0.05, 0.3, linearDepth);

            if (isEyeInWater == 1) depthFade = 0.0;

            // global shelter detection: hide droplets entirely when player is under a block
            // eyeBrightnessSmooth.y is the sky light level at the player's eye position (0-240)
            // sky light 15 (240) = fully outdoors, 14 or less = under a block
            // smoothstep(0.93, 1.0) ensures even a single block above fully removes droplets
            float skyLight = clamp(eyeBrightnessSmooth.y / 240.0, 0.0, 1.0);
            float shelterFade = smoothstep(0.93, 1.0, skyLight);
            depthFade *= shelterFade;

            vec2 uv = texcoord * vec2(aspectRatio, 1.0);
            float totalMask = 0.0;
            
            // multi-layer falling droplets with heads and trails
            for (int i = 0; i < 5; i++) {
                float s = 2.5 + float(i) * 1.3;
                vec2 g = floor(uv * s + vec2(float(i) * 13.7, float(i) * 19.3));
                vec4 seed = texture(noisetex, g * 0.1 + float(i) * 500.0);
                float xOff = fract(seed.r * 31.4 + float(i) * 7.0);
                float speed = 0.3 + seed.g * 0.5;
                float yPos = 1.0 - fract(frameTimeCounter * speed + seed.b * 23.0);

                // fade at edges to hide wrap (yPos 1→0 = top→bottom)
                float fadeIn = 1.0 - smoothstep(0.7, 1.0, yPos);
                float fadeOut = smoothstep(0.0, 0.3, yPos);
                float lifeFade = min(fadeIn, fadeOut);

                float headW = 0.025 + seed.a * 0.02;
                float headX = smoothstep(headW, 0.0, abs(fract(uv.x * s) - xOff));
                float headY = smoothstep(0.035, 0.0, abs(fract(uv.y * s) - yPos));
                float headMask = headX * headY * lifeFade;

                // trail above head (higher fract = higher on screen)
                float trailDist = fract(uv.y * s) - yPos;
                float trailLen = 0.08 + seed.r * 0.04;
                float trailAlpha = clamp(1.0 - trailDist / trailLen, 0.0, 1.0);
                float trailMask = headX * step(0.0, trailDist) * trailAlpha * lifeFade;
                
                totalMask += max(headMask, trailMask * 0.35);
            }
            
            // continuous rivulets
            float riv = texture(noisetex, uv * vec2(0.25, 0.05) + vec2(0.0, frameTimeCounter * 0.06)).r;
            float rivMask = smoothstep(0.5, 0.7, riv) * step(abs(fract(uv.x * 0.15 + frameTimeCounter * 0.02) - 0.5), 0.015);
            totalMask = max(totalMask, rivMask * 0.6) * rainStrength * RAIN_DROPLETS_STRENGTH * depthFade;
            
            // DISTORTION
            distortmask = max(distortmask, totalMask);
            
            // overlay
            vec3 rainColor = vec3(0.75, 0.82, 0.92);
            color = mix(color, rainColor, totalMask);
        }
    #endif
    //////////////////////// HEAT DISTORTION /////////////////////
    #if defined ON_FIRE_DISTORT_EFFECT
      if(exitLava > 0.0){
            vec2 zoomin = 0.5 + (texcoord - 0.5) * (1.0-pow(1.0-clamp(-texcoord.y*0.5+0.75,0.0,1.0),1.0)) * (1.0-pow(1.0-exitLava,2.0));

            vec2 UV = zoomin;

            float flameDistort = texture(noisetex,  UV * vec2(aspectRatio,1.0) - vec2(0.0,frameTimeCounter*0.3)).b * clamp(-texcoord.y*0.3+0.3,0.0,1.0) * ON_FIRE_DISTORT_EFFECT_STRENGTH * exitLava;

            distortmask = max(distortmask, flameDistort);
        }
    #endif

    //////////////////////// APPLY DISTORTION /////////////////////
    // all of the distortion will be based around zooming the UV in the center
    vec2 zoomUV = 0.5 + (texcoord - 0.5) * (1.0 - distortmask);
    
    #ifndef PIXELATED
        vec3 distortedColor = texture(colortex7, zoomUV).rgb;
    #else
        vec2 fragCoord = zoomUV*view_res;
        vec3 distortedColor = texelFetch(colortex7, ivec2(fragCoord)-ivec2(mod(fragCoord, PIXELIZATION_STRENGTH)), 0).rgb;
    #endif

    #if defined WATER_ON_CAMERA_EFFECT || defined ON_FIRE_DISTORT_EFFECT || defined RAIN_DROPLETS_SCREEN
        // apply the distorted color for water, lava, and rain
        if(exitWater > 0.01 || exitLava > 0.01 || rainStrength > 0.01) color = distortedColor;
    #endif


    //////////////////////// APPLY COLOR EFFECTS /////////////////////
    #if defined LOW_HEALTH_EFFECT || defined DAMAGE_TAKEN_EFFECT   
        vec3 distortedColorLuma =  vec3(1.0, 0.0, 0.0) * dot(distortedColor, vec3(0.21, 0.72, 0.07));
    
        #ifdef LOW_HEALTH_EFFECT
            float colorLuma = dot(color, vec3(0.21, 0.72, 0.07));

            vec3 LumaRedEdges = mix(vec3(colorLuma), vec3(1.0, 0.3, 0.3) * distortedColorLuma.r, vignette);

            // apply color effects for when you are at low health
            color = mix(color, LumaRedEdges, mix(vignette * threeHeart, oneHeart, oneHeart));
        #endif

        #ifdef DAMAGE_TAKEN_EFFECT
            color = mix(color, distortedColorLuma, vignette * sqrt(min(MinorDamageTaken,1.0)));
            color = mix(color, distortedColorLuma, sqrt(CriticalDamageTaken));
        #endif

        if(isDead) color = distortedColorLuma * 0.35;
    #endif
}