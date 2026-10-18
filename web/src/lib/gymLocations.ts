export interface GymLocation {
  name: string;
  city: string;
  address: string;
  latitude: number;
  longitude: number;
  hoursLabel: string;
  description: string;
}

/// Ported 1:1 from AppState.swift's gymLocations — static catalog of real
/// club locations the member can switch between on LocationPickerView.
export const gymLocations: GymLocation[] = [
  {
    name: "RC Rezindtsii Arhitektorov",
    city: "Moscow",
    address: "1-ya Tverskaya-Yamskaya, 2/1, Moscow",
    latitude: 55.7766,
    longitude: 37.5926,
    hoursLabel: "until 22:00",
    description: "A full strength floor, free weights, cardio and a group class studio — steps from the metro, open daily.",
  },
  {
    name: "RC Dubai Marina",
    city: "Dubai",
    address: "Marina Walk, Dubai Marina, Dubai",
    latitude: 25.0805,
    longitude: 55.1403,
    hoursLabel: "until 23:00",
    description: "Floor-to-ceiling marina views, a full free-weight floor and a rooftop studio — steps from Dubai Marina Mall.",
  },
  {
    name: "RC Downtown Dubai",
    city: "Dubai",
    address: "Sheikh Mohammed bin Rashid Blvd, Downtown Dubai, Dubai",
    latitude: 25.1972,
    longitude: 55.2744,
    hoursLabel: "until 23:00",
    description: "In the shadow of Burj Khalifa — a premium strength floor, sauna and recovery suite for the downtown crowd.",
  },
  {
    name: "RC New York",
    city: "New York",
    address: "5th Avenue, Flatiron District, New York",
    latitude: 40.741,
    longitude: -73.9896,
    hoursLabel: "until 23:00",
    description: "A Flatiron fixture — free weights, a run club meeting point and the city's best post-workout matcha bar next door.",
  },
  {
    name: "RC Los Angeles",
    city: "Los Angeles",
    address: "Melrose Avenue, West Hollywood, Los Angeles",
    latitude: 34.0836,
    longitude: -118.3617,
    hoursLabel: "until 22:00",
    description: "West Hollywood's go-to strength floor — outdoor turf area, cold plunge and a juice bar on Melrose.",
  },
  {
    name: "RC Miami",
    city: "Miami",
    address: "Ocean Drive, South Beach, Miami",
    latitude: 25.7826,
    longitude: -80.13,
    hoursLabel: "until 23:00",
    description: "Steps from the sand on Ocean Drive — open-air cardio deck, beach bootcamp classes and an on-site smoothie bar.",
  },
];
