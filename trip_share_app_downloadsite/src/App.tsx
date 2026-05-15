/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { BrowserRouter, Routes, Route } from 'react-router-dom';
import HomePage from './pages/HomePage';
import TourRedirect from './pages/TourRedirect';

export default function App() {
  return (
    <BrowserRouter basename="/">
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/tour/:tourId" element={<TourRedirect />} />
      </Routes>
    </BrowserRouter>
  );
}
