import React from "react";

interface LogoProps {
  size?: number;
  className?: string;
}

// Final Vedyx Logo: Enhanced Radar Scan V
export function VedyxLogo({ size = 32, className = "" }: LogoProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      <defs>
        <linearGradient id="radar-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#8b5cf6" />
          <stop offset="50%" stopColor="#6366f1" />
          <stop offset="100%" stopColor="#3b82f6" />
        </linearGradient>
        <filter id="radar-glow">
          <feGaussianBlur stdDeviation="2" result="coloredBlur"/>
          <feMerge>
            <feMergeNode in="coloredBlur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
      </defs>
      
      {/* Shield outline with gradient */}
      <path
        d="M50 10L20 25V48C20 68 30 83 50 92C70 83 80 68 80 48V25L50 10Z"
        stroke="url(#radar-gradient)"
        strokeWidth="3"
        fill="url(#radar-gradient)"
        fillOpacity="0.08"
      >
        <animate attributeName="fill-opacity" values="0.08;0.15;0.08" dur="3s" repeatCount="indefinite" />
      </path>
      
      {/* Large V integrated into shield */}
      <path
        d="M35 35L50 65L65 35"
        stroke="currentColor"
        strokeWidth="4"
        strokeLinecap="round"
        strokeLinejoin="round"
        fill="none"
        opacity="0.3"
      >
        <animate attributeName="opacity" values="0.3;0.5;0.3" dur="2s" repeatCount="indefinite" />
      </path>
      
      {/* Radar scanning line with glow */}
      <line x1="50" y1="50" x2="75" y2="35" stroke="url(#radar-gradient)" strokeWidth="2.5" filter="url(#radar-glow)">
        <animateTransform
          attributeName="transform"
          type="rotate"
          from="0 50 50"
          to="360 50 50"
          dur="3s"
          repeatCount="indefinite"
        />
      </line>
      
      {/* Center point with pulse */}
      <circle cx="50" cy="50" r="4" fill="currentColor">
        <animate attributeName="r" values="4;5;4" dur="1.5s" repeatCount="indefinite" />
      </circle>
      
      {/* Radar circles with gradient */}
      <circle cx="50" cy="50" r="12" stroke="url(#radar-gradient)" strokeWidth="1.5" fill="none" opacity="0.4" />
      <circle cx="50" cy="50" r="20" stroke="url(#radar-gradient)" strokeWidth="1.5" fill="none" opacity="0.3" />
      <circle cx="50" cy="50" r="28" stroke="url(#radar-gradient)" strokeWidth="1.5" fill="none" opacity="0.2" />
      
      {/* Detection blips with V markers */}
      <g opacity="0">
        <circle cx="62" cy="38" r="3" fill="currentColor" />
        <path d="M60 36L62 39L64 36" stroke="currentColor" strokeWidth="1" fill="none" />
        <animate attributeName="opacity" values="0;1;0" dur="2s" repeatCount="indefinite" />
      </g>
      <g opacity="0">
        <circle cx="40" cy="55" r="3" fill="currentColor" />
        <path d="M38 53L40 56L42 53" stroke="currentColor" strokeWidth="1" fill="none" />
        <animate attributeName="opacity" values="0;1;0" dur="2s" begin="0.7s" repeatCount="indefinite" />
      </g>
      <g opacity="0">
        <circle cx="58" cy="62" r="3" fill="currentColor" />
        <path d="M56 60L58 63L60 60" stroke="currentColor" strokeWidth="1" fill="none" />
        <animate attributeName="opacity" values="0;1;0" dur="2s" begin="1.4s" repeatCount="indefinite" />
      </g>
      
      {/* Corner accent nodes */}
      <circle cx="35" cy="35" r="2" fill="currentColor" opacity="0.6">
        <animate attributeName="opacity" values="0.6;1;0.6" dur="2s" repeatCount="indefinite" />
      </circle>
      <circle cx="65" cy="35" r="2" fill="currentColor" opacity="0.6">
        <animate attributeName="opacity" values="0.6;1;0.6" dur="2s" begin="0.5s" repeatCount="indefinite" />
      </circle>
      <circle cx="50" cy="65" r="2" fill="currentColor" opacity="0.6">
        <animate attributeName="opacity" values="0.6;1;0.6" dur="2s" begin="1s" repeatCount="indefinite" />
      </circle>
    </svg>
  );
}
