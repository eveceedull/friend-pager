"""Exercise the served Flutter app with fresh sessions and slow browser rendering."""
from urllib.parse import urlparse

from playwright.sync_api import expect, sync_playwright


def enter_flutter_text(page, label, value):
    field = page.get_by_role('textbox', name=label, exact=True)
    field.click()
    expect(field).to_be_focused()
    # DOM focus precedes Flutter's asynchronous editing activation. The pinned
    # engine initially sets autocorrect=off with no autocapitalize attribute.
    # Activation applies the Dart input configuration and attaches input
    # handlers in the same JS turn. Wait for that observable configuration.
    if field.get_attribute('type') == 'password':
        expect(field).to_have_attribute('autocapitalize', 'off')
    else:
        expect(field).to_have_attribute('autocorrect', 'on')
    field.fill(value)
    expect(field).to_have_value(value)
    field.press('Tab')
    expect(field).not_to_be_focused()
    expect(field).to_have_value(value)


def check_registration(browser, cpu_rate):
    context = browser.new_context(viewport={'width': 1280, 'height': 900}, locale='en-US')
    page = context.new_page()
    external = []

    def route(request):
        if urlparse(request.request.url).hostname not in ('127.0.0.1', 'localhost'):
            external.append(request.request.url)
            request.abort()
        else:
            request.continue_()

    context.route('**/*', route)
    context.new_cdp_session(page).send('Emulation.setCPUThrottlingRate', {'rate': cpu_rate})
    name = f'Compose browser reviewer {cpu_rate}'
    device = 'Synthetic browser device'
    try:
        page.goto('http://127.0.0.1:7357/', wait_until='networkidle')
        page.locator('flt-semantics-placeholder').evaluate('(node) => node.click()')
        enter_flutter_text(page, 'Display name', name)
        enter_flutter_text(page, 'Device label', device)
        enter_flutter_text(page, 'Group password', 'local-group-password')
        # Check what Dart actually submitted, not just the input's DOM value.
        with page.expect_response(lambda r: r.request.method == 'POST'
                and urlparse(r.url).path == '/rest/v1/rpc/join_installation') as joined:
            page.get_by_role('button', name='Join group', exact=True).click()
        response = joined.value
        assert response.status == 200, f'Join RPC failed: HTTP {response.status}'
        submitted = response.request.post_data_json
        assert submitted['p_display_name'] == name, 'Dart did not receive the display name'
        assert submitted['p_device_name'] == device, 'Dart did not receive the device label'
        assert submitted['p_password'] == 'local-group-password', 'Dart did not receive the password'
        page.get_by_role('button', name='SEND ALERT', exact=True).wait_for(timeout=20000)
        page.get_by_text(f'Joined as {name}', exact=True).wait_for()
        page.get_by_text('Connected for live alerts', exact=True).wait_for(timeout=20000)
        assert not external, f'Unexpected external runtime requests: {external}'
        print(f'Compose web registration and Realtime passed at {cpu_rate}x CPU slowdown.')
    except Exception:
        print('CPU slowdown:', cpu_rate, 'Browser URL:', page.url)
        print('Semantics:', page.locator('flt-semantics').evaluate_all('(nodes) => nodes.map(n => ({role:n.getAttribute("role"),label:n.getAttribute("aria-label"),text:n.textContent}))'))
        print('Input state:', page.locator('input').evaluate_all('(nodes) => nodes.map(n => ({label:n.getAttribute("aria-label"),length:n.value.length,focused:n===document.activeElement,capitalization:n.getAttribute("autocapitalize")}))'))
        print('External requests:', external)
        raise
    finally:
        context.close()


if __name__ == '__main__':
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='chrome', headless=True, args=['--no-sandbox'])
        try:
            for cpu_rate in (1, 4, 8):
                check_registration(browser, cpu_rate)
        finally:
            browser.close()
