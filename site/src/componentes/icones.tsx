const base = {
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 2,
  strokeLinecap: "round",
  strokeLinejoin: "round",
  "aria-hidden": true,
} as const;

export const IconeAtualizar = () => (
  <svg {...base}>
    <path d="M21 12a9 9 0 1 1-2.64-6.36" />
    <path d="M21 3v6h-6" />
  </svg>
);
export const IconeSeta = () => (
  <svg {...base}>
    <path d="m9 6 6 6-6 6" />
  </svg>
);
export const IconeTema = () => (
  <svg {...base}>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 3v18" />
    <path d="M12 7a5 5 0 0 1 0 10" fill="currentColor" stroke="none" />
  </svg>
);
export const IconeSair = () => (
  <svg {...base}>
    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
    <path d="m16 17 5-5-5-5" />
    <path d="M21 12H9" />
  </svg>
);
export const Logo = () => (
  <svg viewBox="0 0 24 24" aria-hidden>
    <rect width="24" height="24" rx="6" fill="var(--texto)" />
    <path
      d="M7 16.5V11M12 16.5V7.5M17 16.5V13"
      stroke="var(--superficie)"
      strokeWidth="2.4"
      strokeLinecap="round"
    />
  </svg>
);
