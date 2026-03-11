export function jsonResponse(
  body: unknown,
  init: ResponseInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      ...init.headers,
    },
  });
}

export function errorResponse(
  status: number,
  message: string,
): Response {
  return jsonResponse(
    {
      error: message,
    },
    { status },
  );
}

export function successResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return jsonResponse(body, { status });
}
