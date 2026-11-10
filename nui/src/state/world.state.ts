import { atom, useRecoilState, useRecoilValue } from "recoil";

export interface WorldState {
  enabled: boolean;
  weather: string;
  hour: number;
  minute: number;
  frozen: boolean;
  msPerMinute: number;
  /** Date.now() when this state was received, used to keep the clock ticking */
  receivedAt: number;
}

const worldState = atom<WorldState>({
  key: "worldState",
  default: {
    enabled: false,
    weather: "EXTRASUNNY",
    hour: 12,
    minute: 0,
    frozen: false,
    msPerMinute: 2000,
    receivedAt: Date.now(),
  },
});

export const useWorldState = () => useRecoilState(worldState);
export const useWorldStateValue = () => useRecoilValue(worldState);

/** Returns the current in-game time based on the last state received */
export const getWorldTime = (state: WorldState, now = Date.now()) => {
  let total = state.hour * 60 + state.minute;
  if (!state.frozen) {
    total += Math.floor((now - state.receivedAt) / (state.msPerMinute || 2000));
  }
  total = ((total % 1440) + 1440) % 1440;
  return { hour: Math.floor(total / 60), minute: total % 60 };
};

export const formatTime = (hour: number, minute: number) =>
  `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
