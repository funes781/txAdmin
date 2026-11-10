// Must match TX_WEATHER_TYPES in resource/menu/server/sv_world.lua
export const WEATHER_TYPES = [
  "EXTRASUNNY",
  "CLEAR",
  "NEUTRAL",
  "SMOG",
  "FOGGY",
  "OVERCAST",
  "CLOUDS",
  "CLEARING",
  "RAIN",
  "THUNDER",
  "SNOW",
  "BLIZZARD",
  "SNOWLIGHT",
  "XMAS",
  "HALLOWEEN",
] as const;

export type WeatherType = (typeof WEATHER_TYPES)[number];

const normalize = (str: string) =>
  str
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/ł/g, "l")
    .replace(/[^a-z0-9]/g, "");

/**
 * Finds a weather type from user input, matching either the game id (RAIN)
 * or the translated name (Deszcz). Exact matches win over prefix matches.
 */
export const findWeather = (
  input: string,
  getName: (weather: WeatherType) => string
): WeatherType | undefined => {
  const needle = normalize(input);
  if (!needle) return;
  const candidates = WEATHER_TYPES.map((w) => ({
    id: w,
    keys: [normalize(w), normalize(getName(w))],
  }));
  return (
    candidates.find((c) => c.keys.includes(needle))?.id ??
    candidates.find((c) => c.keys.some((k) => k.startsWith(needle)))?.id
  );
};
