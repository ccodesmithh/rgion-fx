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
            vec2 uv = texcoord * vec2(aspectRatio, 1.0) * 8.0;
            float rainAnim = frameTimeCounter * 1.5;
            
            // two overlapping layers at different scales to break grid
            float dropletMask = 0.0;
            
            // layer 1: coarse droplets
            vec2 g1 = floor(uv);
            vec2 c1 = g1 + 0.5 + texture(noisetex, g1 * 0.1 + rainAnim * 0.05).rg * 0.6;
            float d1 = length(uv - c1);
            float r1 = 0.12 + texture(noisetex, g1 * 0.1 + 50.0).r * 0.08;
            float fall1 = 1.0 - fract(rainAnim * (0.7 + texture(noisetex, g1 * 0.1 + 100.0).r * 0.5));
            float mask1 = smoothstep(r1 + 0.03, r1 - 0.03, d1) * fall1;
            dropletMask += mask1;
            
            // layer 2: fine droplets, offset
            vec2 g2 = floor(uv * 1.7 + vec2(7.3, 13.7));
            vec2 c2 = g2 + 0.5 + texture(noisetex, g2 * 0.15 + rainAnim * 0.07 + 500.0).rg * 0.4;
            float d2 = length(uv * 1.7 - c2);
            float r2 = 0.06 + texture(noisetex, g2 * 0.15 + 200.0).r * 0.04;
            float fall2 = 1.0 - fract(rainAnim * (0.5 + texture(noisetex, g2 * 0.15 + 300.0).r * 0.5));
            dropletMask += smoothstep(r2 + 0.02, r2 - 0.02, d2) * 0.5 * fall2;
            
            // rivulets: irregular vertical streaks
            vec2 rivUV = uv * vec2(0.8, 0.12) + vec2(0.0, rainAnim * 0.25);
            float riv = texture(noisetex, rivUV).r;
            float rivMask = smoothstep(0.55, 0.75, riv) * step(abs(fract(uv.x * 0.6 + rainAnim * 0.08) - 0.5), 0.03);
            
            float totalMask = max(dropletMask, rivMask * 0.5) * rainStrength * RAIN_DROPLETS_STRENGTH;
            
            // ADD DISTORTION for refraction effect (like water exit effect)
            distortmask = max(distortmask, totalMask);
            
            // visible overlay
            vec3 rainColor = vec3(0.8, 0.85, 0.95);
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