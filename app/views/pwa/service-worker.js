// Avisos de produção: o servidor manda { title, options } quando sai uma versão nova de um setor que a pessoa acompanha.
self.addEventListener("push", (event) => {
  if (!event.data) return
  const { title, options } = event.data.json()
  event.waitUntil(self.registration.showNotification(title, options))
})

// Toque no aviso: abre (ou reaproveita) a janela do app na produção daquele dia.
self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const path = event.notification.data?.path || "/production"
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then(async (windows) => {
      for (const client of windows) {
        if ("navigate" in client && "focus" in client) {
          await client.navigate(path)
          return client.focus()
        }
      }
      return clients.openWindow(path)
    })
  )
})
