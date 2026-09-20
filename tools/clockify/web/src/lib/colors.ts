// Curated swatches for project colors. Clockify's `color` field accepts any hex string, so this
// list is a local UX choice, not an API constraint.
export const projectColors: string[] = [
  "#F44336",
  "#E91E63",
  "#9C27B0",
  "#673AB7",
  "#3F51B5",
  "#2196F3",
  "#03A9F4",
  "#00BCD4",
  "#009688",
  "#4CAF50",
  "#8BC34A",
  "#CDDC39",
  "#FFC107",
  "#FF9800",
  "#795548",
  "#607D8B",
];

export const defaultProjectColor = projectColors[5] ?? "#2196F3";
